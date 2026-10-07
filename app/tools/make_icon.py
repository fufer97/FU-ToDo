#!/usr/bin/env python3
"""把一张图片做成 macOS 应用图标（.icns）。

用法：
    python3 tools/make_icon.py <图片> [--out resources/AppIcon.icns] [--no-mask]

默认行为：居中裁成正方形 → 套 macOS 近似圆角遮罩（squircle）→ 生成 iconset → iconutil 打包。
如果图本身已经是设计好的圆角图标，加 --no-mask 跳过遮罩。
"""
import argparse
import pathlib
import subprocess
import sys
import tempfile

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("需要 Pillow：请用 DSH 自带的 Python 运行本脚本")


def squircle_mask(size: int, ratio: float = 0.2237) -> Image.Image:
    big = size * 4
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, big - 1, big - 1], radius=int(big * ratio), fill=255
    )
    return mask.resize((size, size), Image.LANCZOS)


def square(img: Image.Image, size: int, masked: bool) -> Image.Image:
    w, h = img.size
    side = min(w, h)
    img = img.crop(((w - side) // 2, (h - side) // 2, (w - side) // 2 + side, (h - side) // 2 + side))
    img = img.convert("RGBA").resize((size, size), Image.LANCZOS)
    if masked:
        img.putalpha(squircle_mask(size))
    return img


ICONSET = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--out", default="resources/AppIcon.icns")
    ap.add_argument("--no-mask", action="store_true", help="图已是设计好的圆角图标时使用")
    args = ap.parse_args()

    src = Image.open(args.image)
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        iconset = pathlib.Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for name, size in ICONSET:
            square(src, size, not args.no_mask).save(iconset / name)
        subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(out)],
            check=True,
        )

    print(f"✓ 图标已生成：{out}  ({out.stat().st_size // 1024} KB)")
    print("  重新打包：./build.sh dmg")


if __name__ == "__main__":
    main()
