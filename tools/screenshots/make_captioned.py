#!/usr/bin/env python3
"""给 App Store 截图加框:天蓝→薄荷渐变底 + 顶部标语 + 圆角阴影截图。

读  AppStoreScreenshots/<lang>/*.png          (模拟器原图,1284×2778)
写  AppStoreScreenshots/<lang>-captioned/*.png (同尺寸成品,APP_IPHONE_67)

用法:
  python3 tools/screenshots/make_captioned.py                  # 全部语言
  python3 tools/screenshots/make_captioned.py ja ko            # 只做这几个
  python3 tools/screenshots/make_captioned.py --check en       # 渲染 en 并与现有成品比对(调参用)

原图采集见 capture_raw.sh。en / zh-Hans 的成品是 2026-07 手工产出的,本脚本的几何参数
(margin/top/scale/渐变/字色)就是从 en-captioned/1-home.png 反解出来的,重跑可复现。
"""
import argparse
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SHOTS = os.path.join(REPO, "AppStoreScreenshots")

# ---- 画布几何(从现有 en-captioned 成品反解,mean abs diff ≈ 1.8/255) ----
CANVAS = (1284, 2778)          # APP_IPHONE_67
GRADIENT = ((192, 225, 250), (220, 243, 217))   # 顶部天蓝 → 底部薄荷
INK = (64, 56, 51)             # 标语字色
CARD_MARGIN_X = 79             # 截图贴片左右留白 → 宽 1126
CARD_TOP = 291
CARD_RADIUS = 56
CAPTION_CENTER_Y = 136         # 标语的垂直中心
CAPTION_MAX_WIDTH = 1144
CAPTION_MAX_SIZE = 76

# ---- 字体:拉丁走 App 自带的 Roboto Bold,CJK 走系统字体(PIL 不会自动 fallback) ----
ROBOTO_BOLD = os.path.join(REPO, "NoNote/Resource/Roboto-Bold.ttf")
HOME = os.path.expanduser("~")
# 每项是候选链 (路径, ttc 内的 face index),取第一个存在的
CJK_FONTS = {
    "zh-Hans": [(f"{HOME}/Library/Fonts/PingFang.ttc", 8),        # PingFang SC Semibold
                ("/System/Library/Fonts/Hiragino Sans GB.ttc", 2),
                ("/System/Library/Fonts/STHeiti Medium.ttc", 0)],
    "zh-Hant": [(f"{HOME}/Library/Fonts/PingFang.ttc", 7),        # PingFang TC Semibold
                ("/System/Library/Fonts/STHeiti Medium.ttc", 0),
                ("/System/Library/Fonts/Hiragino Sans GB.ttc", 2)],
    "ja": [("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", 0),   # Hiragino Sans W6
           ("/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc", 0)],
    "ko": [("/System/Library/Fonts/AppleSDGothicNeo.ttc", 6)],    # Apple SD Gothic Neo Bold
}

CAPTIONS = {
    "en": {
        "1-home": "Write daily. Watch your flock grow.",
        "2-flock": "Every 7-day streak brings a new sheep",
        "3-editor": "Mood, weather & photos — effortless",
        "4-stats": "See your month at a glance",
        "5-home-dark": "Beautiful in the dark, too",
        "6-privacy": "No accounts, no servers — just your iCloud",
    },
    "zh-Hans": {
        "1-home": "每天一篇日记，养成你的羊群",
        "2-flock": "每坚持 7 天，就有新的小羊加入",
        "3-editor": "心情、天气、照片，一笔记录",
        "4-stats": "一眼看懂你的一个月",
        "5-home-dark": "深色模式，夜里也好看",
        "6-privacy": "无账号无服务器，只存在你的 iCloud",
    },
    "zh-Hant": {
        "1-home": "每天一篇日記，養出你的羊群",
        "2-flock": "每連續 7 天，就有新的小羊加入",
        "3-editor": "心情、天氣、照片，一筆記錄",
        "4-stats": "一眼看懂你的這個月",
        "5-home-dark": "深色模式，夜裡也好看",
        "6-privacy": "無帳號無伺服器，只存在你的 iCloud",
    },
    "ja": {
        "1-home": "毎日ひとこと、ひつじが増えていく",
        "2-flock": "7日続けるたび、新しいひつじが仲間に",
        "3-editor": "気分・天気・写真も、ひと手間なし",
        "4-stats": "ひと月をひと目で",
        "5-home-dark": "ダークモードもきれい",
        "6-privacy": "アカウント不要。あなたの iCloud だけ",
    },
    "ko": {
        "1-home": "매일 한 편, 양 떼가 자라요",
        "2-flock": "7일 이어 쓰면 새 양이 찾아와요",
        "3-editor": "기분·날씨·사진까지 한 번에",
        "4-stats": "한 달을 한눈에",
        "5-home-dark": "어두운 화면에서도 예쁘게",
        "6-privacy": "계정도 서버도 없이, 당신의 iCloud에만",
    },
    "es": {
        "1-home": "Escribe cada día. Mira crecer tu rebaño.",
        "2-flock": "Cada racha de 7 días trae una oveja",
        "3-editor": "Ánimo, tiempo y fotos — sin esfuerzo",
        "4-stats": "Tu mes de un vistazo",
        "5-home-dark": "También precioso a oscuras",
        "6-privacy": "Sin cuentas ni servidores — solo tu iCloud",
    },
}

# 拉丁/数字/标点走 Roboto,其余(汉字/かな/한글)走 CJK 字体
LATIN_RUN = re.compile(r"[\x20-\x7E -ɏ–—‘-”]+")


def cjk_font_path(lang):
    for path, index in CJK_FONTS.get(lang, []):
        if os.path.exists(path):
            return path, index
    return None


def load_fonts(lang, size):
    latin = ImageFont.truetype(ROBOTO_BOLD, size)
    cjk = None
    found = cjk_font_path(lang)
    if found:
        cjk = ImageFont.truetype(found[0], size, index=found[1])
    return latin, cjk


def runs(text):
    """把标语切成 (片段, 是否拉丁) 的序列,好按段换字体。"""
    out, pos = [], 0
    for m in LATIN_RUN.finditer(text):
        if m.start() > pos:
            out.append((text[pos:m.start()], False))
        out.append((m.group(), True))
        pos = m.end()
    if pos < len(text):
        out.append((text[pos:], False))
    return out


def measure(draw, pieces, latin, cjk):
    width = 0
    for piece, is_latin in pieces:
        font = latin if (is_latin or cjk is None) else cjk
        width += draw.textlength(piece, font=font)
    return width


def draw_caption(img, text, lang):
    draw = ImageDraw.Draw(img)
    pieces = runs(text)
    size = CAPTION_MAX_SIZE
    while size > 24:
        latin, cjk = load_fonts(lang, size)
        if measure(draw, pieces, latin, cjk) <= CAPTION_MAX_WIDTH:
            break
        size -= 2
    latin, cjk = load_fonts(lang, size)
    total = measure(draw, pieces, latin, cjk)
    x = (img.width - total) / 2
    for piece, is_latin in pieces:
        font = latin if (is_latin or cjk is None) else cjk
        draw.text((x, CAPTION_CENTER_Y), piece, font=font, fill=INK, anchor="lm")
        x += draw.textlength(piece, font=font)
    return size


# 可选:用 tools/artgen 生成的插画底图替代纯渐变。设成 None 就回到原来的渐变。
BACKDROP = os.environ.get("NODIARY_BACKDROP")           # Marketing/Art 下的文件名(不含 .png)
CARD_LAYOUT = os.environ.get("NODIARY_CARD_LAYOUT", "tight")   # tight = 原版几何, roomy = 缩小贴片露出更多底图

LAYOUTS = {
    # margin_x, card_top —— roomy 把手机缩小上移,让插画底图真的能被看见
    "tight": (79, 291),
    "roomy": (150, 372),
}


def backdrop_background():
    """把插画底图按 cover 方式填满画布(等比缩放取中心裁切,不拉伸)。"""
    path = os.path.join(REPO, "Marketing", "Art", f"{BACKDROP}.png")
    if not os.path.exists(path):
        sys.exit(f"找不到底图 {path}(先跑 tools/artgen/generate.py)")
    art = Image.open(path).convert("RGB")
    cw, ch = CANVAS
    scale = max(cw / art.width, ch / art.height)
    art = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
    left = (art.width - cw) // 2
    top = (art.height - ch) // 2
    return art.crop((left, top, left + cw, top + ch))


def gradient_background():
    top, bottom = GRADIENT
    w, h = CANVAS
    # 先画 1px 宽的竖条再横向拉伸——比逐像素快得多
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / (h - 1)
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return strip.resize((w, h))


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1],
                                          radius=radius, fill=255)
    return mask


def compose(raw_path, caption, lang):
    canvas = backdrop_background() if BACKDROP else gradient_background()
    margin_x, card_top = LAYOUTS[CARD_LAYOUT]
    raw = Image.open(raw_path).convert("RGB")

    card_w = CANVAS[0] - 2 * margin_x
    card_h = round(raw.height * card_w / raw.width)
    card = raw.resize((card_w, card_h), Image.LANCZOS)
    mask = rounded_mask((card_w, card_h), CARD_RADIUS)

    # 柔和投影:把圆角形状放大一圈后模糊,压在贴片下面
    shadow = Image.new("L", CANVAS, 0)
    shadow.paste(mask.point(lambda v: v * 90 // 255), (margin_x, card_top + 14))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas.paste(Image.new("RGB", CANVAS, (70, 90, 90)), (0, 0), shadow)

    canvas.paste(card, (margin_x, card_top), mask)
    size = draw_caption(canvas, caption, lang)
    return canvas, size


def build(lang, check=False):
    src = os.path.join(SHOTS, lang)
    if not os.path.isdir(src):
        print(f"跳过 {lang}: 没有原图目录 {src}")
        return 0
    out_dir = os.path.join(SHOTS, f"{lang}-captioned")
    os.makedirs(out_dir, exist_ok=True)
    captions = CAPTIONS.get(lang)
    if not captions:
        print(f"跳过 {lang}: CAPTIONS 里没有这个语言的标语")
        return 0

    made = 0
    for name in sorted(os.listdir(src)):
        if not name.endswith(".png"):
            continue
        stem = name[:-4]
        if stem not in captions:
            print(f"  ! {lang}/{name}: CAPTIONS 里没有 '{stem}',跳过")
            continue
        img, size = compose(os.path.join(src, name), captions[stem], lang)
        out_path = os.path.join(out_dir, name)
        if check:
            existing = os.path.join(out_dir, name)
            if os.path.exists(existing):
                import numpy as np
                a = np.asarray(img).astype(int)
                b = np.asarray(Image.open(existing).convert("RGB")).astype(int)
                print(f"  {lang}/{name}: 字号 {size}  与现有成品 mean|Δ| = "
                      f"{abs(a - b).mean():.2f}/255")
            img.save(out_path.replace(".png", ".check.png"))
        else:
            img.save(out_path)
            print(f"  {lang}/{name} ✓ (字号 {size})")
        made += 1
    return made


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("langs", nargs="*", default=None,
                    help="要处理的语言目录名(默认全部有原图的)")
    ap.add_argument("--check", action="store_true",
                    help="不覆盖成品:另存 *.check.png 并打印与现有成品的像素差")
    args = ap.parse_args()

    langs = args.langs or [l for l in CAPTIONS if os.path.isdir(os.path.join(SHOTS, l))]
    if not langs:
        sys.exit(f"{SHOTS} 下没有任何原图目录——先跑 capture_raw.sh")
    total = 0
    for lang in langs:
        print(f"{lang}:")
        total += build(lang, args.check)
    print(f"共 {total} 张")


if __name__ == "__main__":
    main()
