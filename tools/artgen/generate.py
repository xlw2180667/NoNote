#!/usr/bin/env python3
"""通用本地 AI 美术生成管线（FLUX.1-schnell，Apache-2.0 可商用）。

从同目录 artgen.json 读配置与资产清单，批量生成风格统一的游戏/应用素材：
  · cutout  模式：抠透明底 → alpha 裁剪 → 留边居中方图 → 导出 @3x/@2x/@1x
  · texture 模式：满幅贴图（背景/房间/面板），不抠底单张导出
固定基准 seed + 每资产名稳定偏移 → 可复现；改 prompt 即换产物。

用法：
  python generate.py                 # 全部清单（已存在跳过）
  python generate.py --only a,b      # 只生成指定 name（存在也重生成）
  python generate.py --force         # 全部重生成
  python generate.py --flip a,b      # 强制水平翻转（cutout 朝向不对时）

模型经环境变量 ARTGEN_MODEL=flux|sdxl 选择（默认 flux）；权重缓存在
~/.cache/huggingface（跨项目共享，只下一次）。venv 建议全局共享：
  python3 -m venv ~/.venvs/artgen && source ~/.venvs/artgen/bin/activate
  pip install -r requirements.txt
⚠️ 出货素材只可用可商用模型：FLUX.1-schnell(Apache-2.0)/SDXL base(OpenRAIL-M)；
   禁用 FLUX.1-dev（非商用）。
"""
import argparse
import hashlib
import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONFIG_PATH = HERE / "artgen.json"
MODEL = os.environ.get("ARTGEN_MODEL", "flux").lower()

# ============================== 配置 ==============================

def load_config():
    if not CONFIG_PATH.exists():
        raise SystemExit(f"缺 {CONFIG_PATH}：从 artgen.json.example 复制一份并按项目改")
    data = json.loads(CONFIG_PATH.read_text())
    cfg = data.get("config") or {}
    assets = data.get("assets") or []
    if not cfg.get("style_anchor"):
        raise SystemExit("config.style_anchor 必填：全项目风格一致性的锚点（见 SKILL.md 的设计指引）")
    if not assets:
        raise SystemExit("assets 清单为空")
    return cfg, assets


def out_dir(cfg) -> Path:
    return (HERE / cfg.get("out_dir", "./out")).resolve()


def stable_seed(cfg, name: str) -> int:
    base = int(cfg.get("base_seed", 20260101))
    return base + int(hashlib.md5(name.encode()).hexdigest(), 16) % 1000


# ============================== 生成 ==============================

def build_pipeline():
    import torch
    device = "mps" if torch.backends.mps.is_available() else (
        "cuda" if torch.cuda.is_available() else "cpu")
    low_mem = bool(os.environ.get("ARTGEN_LOW_MEM"))
    if MODEL == "sdxl":
        from diffusers import StableDiffusionXLPipeline
        print(f"[artgen] device={device} model=stabilityai/stable-diffusion-xl-base-1.0 "
              "(CreativeML OpenRAIL-M, 可商用)")
        pipe = StableDiffusionXLPipeline.from_pretrained(
            "stabilityai/stable-diffusion-xl-base-1.0",
            torch_dtype=torch.bfloat16, variant="fp16", use_safetensors=True,
        ).to(device)
        if low_mem:
            pipe.enable_attention_slicing()
    else:
        from diffusers import FluxPipeline
        print(f"[artgen] device={device} model=black-forest-labs/FLUX.1-schnell (Apache-2.0)")
        pipe = FluxPipeline.from_pretrained(
            "black-forest-labs/FLUX.1-schnell", torch_dtype=torch.bfloat16,
        ).to(device)
        if low_mem:
            pipe.enable_attention_slicing()
            pipe.enable_model_cpu_offload()
    return pipe, device, torch


def generate_one(cfg, pipe, torch, prompt: str, seed: int, width: int = None, height: int = None,
                 anchor: bool = True):
    # 锚点尾部的 "plain flat white background" 只适用于 cutout；
    # 满幅 texture 资产用 no_anchor 跳过，风格词写进自身 prompt
    full = f"{prompt}, {cfg['style_anchor']}" if anchor else prompt
    gen = torch.Generator(device="cpu").manual_seed(seed)  # MPS 用 cpu generator 保证可复现
    size = int(cfg.get("gen_size", 1024))
    # 每资产可覆盖宽高（texture 竖幅背景等）；需为 16 的倍数
    w = int(width or size)
    h = int(height or size)
    if MODEL == "sdxl":
        out = pipe(prompt=full, negative_prompt=cfg.get("negative", ""),
                   height=h, width=w,
                   num_inference_steps=30, guidance_scale=7.0, generator=gen)
    else:
        out = pipe(prompt=full, height=h, width=w,
                   num_inference_steps=4, guidance_scale=0.0,   # schnell 蒸馏模型
                   max_sequence_length=256, generator=gen)
    return out.images[0]


# ============================== 后处理与导出 ==============================

def cutout_and_trim(cfg, img, flip: bool):
    """rembg 抠底 → alpha 裁剪 → 留边居中方图 → 朝向。"""
    from rembg import remove
    from PIL import Image
    rgba = remove(img.convert("RGB")).convert("RGBA")
    alpha = rgba.split()[-1]
    bbox = alpha.getbbox()
    if bbox:
        rgba = rgba.crop(bbox)
    w, h = rgba.size
    side = max(w, h)
    pad = int(side * float(cfg.get("margin", 0.06)))
    canvas = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    canvas.alpha_composite(rgba, ((canvas.width - w) // 2, (canvas.height - h) // 2))
    if flip:
        canvas = canvas.transpose(Image.FLIP_LEFT_RIGHT)
    return canvas


def export_cutout(cfg, canvas, name: str):
    from PIL import Image
    dest = out_dir(cfg)
    dest.mkdir(parents=True, exist_ok=True)
    written = []
    sizes = cfg.get("sizes") or {"@3x": 540, "@2x": 360, "": 180}
    for suffix, longest in sizes.items():
        scale = longest / max(canvas.size)
        size = (max(1, round(canvas.width * scale)), max(1, round(canvas.height * scale)))
        resized = canvas.resize(size, Image.LANCZOS)
        fname = f"{name}{suffix}.png"
        resized.save(dest / fname)
        written.append(fname)
    return written


def export_texture(cfg, img, name: str):
    """满幅贴图：不抠底不裁剪，单张高分导出（使用侧显式设尺寸/平铺）。"""
    dest = out_dir(cfg)
    dest.mkdir(parents=True, exist_ok=True)
    img.convert("RGBA").save(dest / f"{name}.png")
    return [f"{name}.png"]


def make_contactsheet(tiles, path):
    """tiles: [(name, pil_rgba)] → 带标签联系表，供人工挑图"""
    from PIL import Image, ImageDraw
    if not tiles:
        return False
    cell, cols = 200, 6
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (30, 40, 48, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(tiles):
        r, c = divmod(i, cols)
        thumb = im.copy()
        thumb.thumbnail((cell - 16, cell - 34), Image.LANCZOS)
        sheet.alpha_composite(thumb.convert("RGBA"),
                              (c * cell + (cell - thumb.width) // 2,
                               r * cell + (cell - 30 - thumb.height) // 2 + 4))
        draw.text((c * cell + 6, r * cell + cell - 22), name, fill=(230, 230, 230, 255))
    sheet.convert("RGB").save(path)
    return True


# ============================== 主流程 ==============================

def main():
    p = argparse.ArgumentParser()
    p.add_argument("only_pos", nargs="?", default=None)
    p.add_argument("--only", default=None, help="逗号分隔 name，只生成这些（存在也重生成）")
    p.add_argument("--force", action="store_true", help="已存在也重生成")
    p.add_argument("--flip", default="", help="逗号分隔 name，cutout 强制水平翻转")
    args = p.parse_args()

    cfg, assets = load_config()
    only = args.only or args.only_pos
    only_names = {x.strip() for x in only.split(",")} if only else None
    flip_names = {x.strip() for x in args.flip.split(",") if x.strip()}
    dest = out_dir(cfg)

    todo = []
    for a in assets:
        name = a["name"]
        if only_names and name not in only_names:
            continue
        exists = (dest / f"{name}.png").exists() or (dest / f"{name}@3x.png").exists()
        if exists and not args.force and not only_names:
            print(f"[skip] {name}: 已存在（--force 覆盖）")
            continue
        todo.append(a)
    if not todo:
        print("[artgen] 没有需要生成的资产。")
        return

    pipe, device, torch = build_pipeline()
    tiles, ok = [], []
    for a in todo:
        name, mode = a["name"], a.get("mode", "cutout")
        seed = stable_seed(cfg, name)
        print(f"[gen] {name} ({mode})  seed={seed}")
        try:
            img = generate_one(cfg, pipe, torch, a["prompt"], seed,
                               width=a.get("width"), height=a.get("height"),
                               anchor=not a.get("no_anchor", False))
            if mode == "texture":
                written = export_texture(cfg, img, name)
                tiles.append((name, img.convert("RGBA")))
            else:
                canvas = cutout_and_trim(cfg, img, flip=(name in flip_names or a.get("flip") is True))
                written = export_cutout(cfg, canvas, name)
                tiles.append((name, canvas))
            ok.append((name, written))
            print(f"      -> {', '.join(written)}")
        except Exception as e:
            print(f"[ERR] {name}: {e}")

    sheet = HERE / "_contactsheet.png"
    made = make_contactsheet(tiles, sheet)
    print("\n==== 生成完成 ====")
    print(f"成功 {len(ok)}/{len(todo)} 个")
    for name, written in ok:
        print(f"  {name}: {', '.join(written)}")
    print(f"contactsheet: {'已生成 ' + str(sheet) if made else '未生成'}")


if __name__ == "__main__":
    main()
