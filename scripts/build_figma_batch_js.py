#!/usr/bin/env python3
"""Собирает один JS для use_figma: несколько экранов за один вызов (лимит ~45k символов кода)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = json.loads((ROOT / "docs/figma-screenshots/FIGMA_NODE_MAP.json").read_text())


def main() -> None:
    keys = sys.argv[1:]
    if not keys:
        sys.exit("Usage: build_figma_batch_js.py key1 key2 ...")
    items = []
    for k in keys:
        real_b64 = ROOT / f"docs/figma-screenshots/encoded/{k}.b64"
        ph_b64 = ROOT / f"docs/figma-screenshots/placeholders/{k}.b64"
        b64_path = real_b64 if real_b64.is_file() else ph_b64
        b64 = b64_path.read_text().strip()
        items.append({"key": k, "id": MAP[k], "b64": b64})
    items_js = json.dumps(items)
    code = f"""
const items = {items_js};
const results = [];
for (const it of items) {{
  try {{
    const bytes = Uint8Array.from(atob(it.b64), (c) => c.charCodeAt(0));
    const frame = await figma.getNodeByIdAsync(it.id);
    if (!frame || frame.type !== 'FRAME') {{
      results.push({{ key: it.key, err: 'not frame', id: it.id }});
      continue;
    }}
    frame.clipsContent = true;
    for (const c of [...frame.children]) {{
      if (c.name === 'AppScreenshot') c.remove();
    }}
    const rect = figma.createRectangle();
    rect.name = 'AppScreenshot';
    rect.resize(frame.width, frame.height);
    rect.x = 0;
    rect.y = 0;
    const image = await figma.createImageAsync(bytes);
    rect.fills = [{{ type: 'IMAGE', imageHash: image.hash, scaleMode: 'FILL' }}];
    frame.appendChild(rect);
    rect.moveToFront();
    results.push({{ key: it.key, ok: true, frameId: it.id, rectId: rect.id }});
  }} catch (e) {{
    results.push({{ key: it.key, err: String(e) }});
  }}
}}
return {{ results }};
"""
    sys.stdout.write(code.strip())


if __name__ == "__main__":
    main()
