#!/usr/bin/env python3
"""备用 App 图标(Pro):把换装 SVG 戴到图标小羊头上。

图标里的羊和 App 内的心情小羊(SheepMoodIcon)是同一套几何,所以位置直接读
FlockService.swift 里的 `headPlacement` 表 —— 改一处,App 内和图标一起变。

    python3 tools/appicons/make_icons.py            # 生成 appiconset + 预览 imageset
    python3 tools/appicons/make_icons.py --sheet out.png   # 12 件全戴一遍的对照表,调位置用

依赖:rsvg-convert(brew install librsvg)、Pillow。
"""
import argparse
import json
import re
import subprocess
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "Assets.xcassets"
BASE_DAY = ASSETS / "AppIcon.appiconset/AppIcon1024.png"
BASE_NIGHT = ASSETS / "AppIcon.appiconset/AppIcon1024-dark.png"

# 图标小羊 = SheepMoodIcon 放大:脸宽 0.48s ≈ 340px → s ≈ 708,中心 (512, 567)。
S, CX, CY = 708, 512, 567
PREVIEW_PX = 180

# name → (costume asset 名, 白天底图)。顺序就是 App 内图标选择器的顺序。
# Night 不戴东西:深色模式下系统图标本来就是夜景,这个是"一直是夜晚"。
ICONS = [
    ("Night", None, BASE_NIGHT),
    ("SantaHat", "costume_santahat", BASE_DAY),
    ("FlowerCrown", "costume_flowercrown", BASE_DAY),
    ("StrawHat", "costume_strawhat", BASE_DAY),
    ("Beret", "costume_beret", BASE_DAY),
    ("Beanie", "costume_beanie", BASE_DAY),
    ("Sunglasses", "costume_sunglasses", BASE_DAY),
    ("Headphones", "costume_headphones", BASE_DAY),
]


def head_placements():
    src = (REPO / "NoNote/Services/FlockService.swift").read_text()
    block = src.split("var headPlacement: Placement?", 1)[1].split("\n    }\n", 1)[0]
    rx = re.compile(r'asset: "(\w+)",\s*widthFactor: ([\d.]+),\s*x: (-?[\d.]+),\s*y: (-?[\d.]+)')
    table = {m[0]: tuple(float(v) for v in m[1:]) for m in rx.findall(block)}
    if len(table) != 12:
        sys.exit(f"headPlacement 解析到 {len(table)} 件,应为 12 —— FlockService.swift 格式变了?")
    return table


def render_svg(asset, width):
    svg = next((ASSETS / f"{asset}.imageset").glob("*.svg"))
    png = subprocess.run(["rsvg-convert", "-w", str(width), str(svg)],
                         check=True, capture_output=True).stdout
    return Image.open(BytesIO(png)).convert("RGBA")


def dress(base, asset, table):
    img = Image.open(base).convert("RGBA")
    if asset is None:
        return img
    w, x, y = table[asset]
    art = render_svg(asset, round(S * w))
    cx, cy = CX + x * S, CY + y * S
    img.alpha_composite(art, (round(cx - art.width / 2), round(cy - art.height / 2)))
    return img


def write_iconset(name, light, dark):
    d = ASSETS / f"AppIcon-{name}.appiconset"
    d.mkdir(exist_ok=True)
    light.convert("RGB").save(d / "icon.png", optimize=True)
    dark.convert("RGB").save(d / "icon-dark.png", optimize=True)
    (d / "Contents.json").write_text(json.dumps({
        "images": [
            {"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}],
             "filename": "icon-dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def write_preview(name, img):
    # 选择器里显示用。appiconset 不能用 UIImage(named:) 可靠地读出来。
    d = ASSETS / f"iconPreview_{name}.imageset"
    d.mkdir(exist_ok=True)
    img.resize((PREVIEW_PX, PREVIEW_PX), Image.LANCZOS).convert("RGB").save(d / "preview.png", optimize=True)
    (d / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "preview.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def contact_sheet(out, table):
    tiles = [dress(BASE_DAY, a, table).resize((256, 256), Image.LANCZOS) for a in sorted(table)]
    sheet = Image.new("RGB", (256 * 4, 256 * 3), "white")
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 4) * 256, (i // 4) * 256))
    sheet.save(out)
    print("对照表:", out, "顺序:", ", ".join(sorted(table)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet")
    args = ap.parse_args()
    table = head_placements()
    if args.sheet:
        return contact_sheet(args.sheet, table)
    write_preview("Default", Image.open(BASE_DAY))
    for name, asset, base in ICONS:
        light = dress(base, asset, table)
        dark = dress(BASE_NIGHT, asset, table)
        write_iconset(name, light, dark)
        write_preview(name, light)
        print("AppIcon-" + name)


if __name__ == "__main__":
    main()
