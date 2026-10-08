#!/usr/bin/env python3
"""Check the site is sound before deploying. Run: python3 verify.py"""
import pathlib, re, subprocess, sys, shutil

HERE = pathlib.Path(__file__).parent
PAGES = ["sales.html", "access.html", "access-bundle.html",
         "privacy.html", "terms.html", "app/index.html"]
fails, warns = [], []


def check_refs(page, text):
    """Every local href/src must point at a file that exists."""
    base = (HERE / page).parent
    for attr, val in re.findall(r'(?:href|src)="([^"]+)"', text) and \
            [("", v) for v in re.findall(r'(?:href|src)="([^"]+)"', text)]:
        if val.startswith(("http", "data:", "mailto:", "#", "//")):
            continue
        target = (base / val.split("?")[0].split("#")[0]).resolve()
        if not target.exists():
            fails.append(f"{page}: broken reference -> {val}")


def check_js(page, text):
    """Every inline script must parse."""
    if not shutil.which("node"):
        warns.append("node not found, skipped JS syntax checks")
        return
    for i, src in enumerate(re.findall(r"<script>(.*?)</script>", text, re.S)):
        tmp = pathlib.Path(f"/tmp/_v_{page.replace('/', '_')}_{i}.js")
        tmp.write_text(src)
        r = subprocess.run(["node", "--check", str(tmp)], capture_output=True, text=True)
        if r.returncode:
            fails.append(f"{page}: script {i} syntax error -> "
                         f"{r.stderr.strip().splitlines()[-1] if r.stderr else '?'}")
        tmp.unlink(missing_ok=True)


for page in PAGES:
    p = HERE / page
    if not p.exists():
        fails.append(f"{page}: missing")
        continue
    text = p.read_text()
    check_refs(page, text)
    check_js(page, text)
    if "<title>" not in text:
        warns.append(f"{page}: no <title>")
    if 'name="viewport"' not in text:
        fails.append(f"{page}: no viewport meta — will render desktop-wide on phones")

# placeholders
for page in PAGES:
    p = HERE / page
    if p.exists():
        for tok in sorted(set(re.findall(r"YOUR_[A-Z_]+", p.read_text()))):
            warns.append(f"{page}: placeholder {tok}")

# funnel wiring
sales = (HERE / "sales.html").read_text()
if "whop.com/sales-ascent/the-booked-call-engine/" not in sales:
    fails.append("sales.html: guide checkout link missing")
if "1-1-call" not in sales:
    fails.append("sales.html: bundle checkout link missing")
if "calendly.com" not in (HERE / "access-bundle.html").read_text():
    fails.append("access-bundle.html: no Calendly link")

# the duration mismatch is a correctness problem, not a placeholder
ab = (HERE / "access-bundle.html").read_text()
if "/30min" in ab and "Sixty minutes" in ab:
    fails.append("access-bundle.html: sells 60 minutes, books a 30-minute slot")

# PWA
for f in ["app/manifest.json", "app/sw.js", "app/icon-192.png", "app/icon-512.png"]:
    if not (HERE / f).exists():
        fails.append(f"{f}: missing — home-screen install will fail")

print(f"{len(PAGES)} pages checked\n")
if warns:
    print("WARNINGS (deploy works, but incomplete):")
    for w in warns:
        print("  ·", w)
    print()
if fails:
    print("FAILURES (fix before deploying):")
    for f in fails:
        print("  ✗", f)
    sys.exit(1)
print("No failures." + ("  Clear the warnings above before driving traffic." if warns else ""))
