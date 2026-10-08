#!/usr/bin/env python3
"""Regenerate the standalone preview and the deployable zip. Run after configure.py."""
import base64, mimetypes, pathlib, re, zipfile

HERE = pathlib.Path(__file__).parent
SKIP = {"booked-call-engine-site.zip", "booked-call-engine-images.zip",
        "preview-sales.html", "build-app.py", "make-images.py",
        "configure.py", "verify.py", "package.py"}

# 1. self-contained preview
def inline(m):
    src = m.group(1)
    if src.startswith(("data:", "http")):
        return m.group(0)
    p = HERE / src
    if not p.exists():
        return m.group(0)
    mt = mimetypes.guess_type(src)[0] or "image/png"
    b64 = base64.b64encode(p.read_bytes()).decode()
    return m.group(0).replace(src, f"data:{mt};base64,{b64}")

html = (HERE / "sales.html").read_text()
out = re.sub(r'src="([^"]+\.(?:png|jpg|jpeg|webp))"', inline, html)
(HERE / "preview-sales.html").write_text(out)
print(f"preview-sales.html   {len(out)//1024}KB")

# 2. deployable zip
zp = HERE / "booked-call-engine-site.zip"
n = 0
with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(HERE.rglob("*")):
        if p.is_dir() or p.name in SKIP or ".git" in p.parts or p.suffix == ".md":
            continue
        z.write(p, p.relative_to(HERE).as_posix())
        n += 1
print(f"booked-call-engine-site.zip   {n} files, {zp.stat().st_size//1024}KB")
