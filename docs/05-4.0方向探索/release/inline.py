#!/usr/bin/env python3
"""把 release-4.0.html 的占位符替换为内嵌资源，输出单文件发布页。"""
import base64, pathlib

src = pathlib.Path(__file__).parent
out = pathlib.Path(__file__).resolve().parent.parent.parent / "04-版本发布" / "FUToDo 4.0发布页.html"

html = (src / "release-4.0.html").read_text(encoding="utf-8")

def b64(name: str) -> str:
    data = (src / name).read_bytes()
    return "data:image/png;base64," + base64.b64encode(data).decode()

repl = {
    "{{GSAP}}": (src / "gsap.min.js").read_text(encoding="utf-8"),
    "{{ST}}": (src / "ScrollTrigger.min.js").read_text(encoding="utf-8"),
    "{{IMG_HERO}}": b64("img-hero.png"),
    "{{IMG_OLD}}": b64("old-2.0.png"),
    "{{IMG_INPUT}}": b64("img-input.png"),
    "{{IMG_POOL}}": b64("img-pool.png"),
    "{{IMG_CYBER}}": b64("img-cyber.png"),
}
for k, v in repl.items():
    assert k in html, f"missing placeholder {k}"
    html = html.replace(k, v)

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(html, encoding="utf-8")
print(f"✓ {out}  ({out.stat().st_size/1024:.0f} KB)")
