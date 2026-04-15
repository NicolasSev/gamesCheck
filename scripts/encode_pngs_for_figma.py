#!/usr/bin/env python3
"""PNG из docs/figma-screenshots → JPEG (sips) → base64 в encoded/<key>.b64 для use_figma (лимит ~48k)."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHOT_DIR = ROOT / "docs/figma-screenshots"
MAP = json.loads((SHOT_DIR / "FIGMA_NODE_MAP.json").read_text())
ENCODED = SHOT_DIR / "encoded"
MAX_B64 = 48_000


def compress_to_jpeg(png: Path, jpeg: Path) -> None:
    subprocess.run(
        ["sips", "-s", "format", "jpeg", "-s", "formatOptions", "70", str(png), "--out", str(jpeg)],
        check=True,
        capture_output=True,
    )


def main() -> None:
    ENCODED.mkdir(parents=True, exist_ok=True)
    for key in MAP:
        png = SHOT_DIR / f"{key}.png"
        if not png.is_file():
            print(f"skip (no PNG): {key}", file=sys.stderr)
            continue
        jpeg = ENCODED / f"{key}.jpg"
        compress_to_jpeg(png, jpeg)
        data = jpeg.read_bytes()
        b64 = __import__("base64").b64encode(data).decode("ascii")
        if len(b64) > MAX_B64:
            for q in ("55", "45", "35", "25"):
                subprocess.run(
                    ["sips", "-s", "format", "jpeg", "-s", "formatOptions", q, str(png), "--out", str(jpeg)],
                    check=True,
                    capture_output=True,
                )
                data = jpeg.read_bytes()
                b64 = __import__("base64").b64encode(data).decode("ascii")
                if len(b64) <= MAX_B64:
                    break
        if len(b64) > MAX_B64:
            print(f"ERROR: {key} still too large ({len(b64)} chars)", file=sys.stderr)
            sys.exit(1)
        (ENCODED / f"{key}.b64").write_text(b64)
        print(f"ok {key} -> {len(b64)} chars")


if __name__ == "__main__":
    main()
