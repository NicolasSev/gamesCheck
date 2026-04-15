#!/usr/bin/env python3
"""Собирает JS для use_figma: вставка AppScreenshot (JPEG base64) в FRAME по node id."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "docs/figma-screenshots/FIGMA_NODE_MAP.json"


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: build_figma_image_js.py <key> <path-to-.b64>", file=sys.stderr)
        sys.exit(1)
    key = sys.argv[1]
    b64_path = Path(sys.argv[2])
    node_id = json.loads(MAP_PATH.read_text())[key]
    b64 = b64_path.read_text().strip()
    b64_js = json.dumps(b64)
    code = f"""
const frameId = {json.dumps(node_id)};
const b64 = {b64_js};
const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
const frame = await figma.getNodeByIdAsync(frameId);
if (!frame || frame.type !== 'FRAME') return {{ err: 'not frame', frameId }};
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
return {{ ok: true, frameId, rectId: rect.id, key: {json.dumps(key)} }};
"""
    sys.stdout.write(code.strip())


if __name__ == "__main__":
    main()
