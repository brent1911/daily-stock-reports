import subprocess, os, pathlib

OUT = pathlib.Path("/home/user/daily-stock-reports/offers/booked-call-engine/img")
OUT.mkdir(parents=True, exist_ok=True)
CHROME = "/opt/pw-browsers/chromium"

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:100%;height:100%}
body{background:#0e1014;color:#f2f4f7;
  font-family:"Liberation Sans",Helvetica,Arial,sans-serif;
  display:flex;flex-direction:column;justify-content:space-between;
  position:relative;overflow:hidden}
.glow{position:absolute;width:150%;height:150%;top:-55%;right:-60%;
  background:radial-gradient(circle,rgba(255,122,60,.17) 0%,rgba(255,122,60,0) 62%);pointer-events:none}
.pad{padding:var(--pad);position:relative;z-index:2}
.eyebrow{color:#ff7a3c;font-size:var(--eb);font-weight:700;
  letter-spacing:.2em;text-transform:uppercase}
h1{font-size:var(--h1);line-height:.98;letter-spacing:-.035em;font-weight:800;margin-top:var(--gap)}
.sub{color:#aab2c0;font-size:var(--sub);line-height:1.4;margin-top:var(--gap2);max-width:var(--subw)}
.rule{height:3px;background:#ff7a3c;width:var(--rw);margin-top:var(--gap)}
.foot{display:flex;align-items:center;gap:var(--fg);
  border-top:1px solid #262b35;padding-top:var(--fp);color:#8b93a3;
  font-size:var(--ft);letter-spacing:.1em;text-transform:uppercase;font-weight:600}
.foot b{color:#f2f4f7;font-weight:800}
.dot{width:5px;height:5px;border-radius:50%;background:#394150}
.funnel{display:flex;align-items:flex-end;gap:var(--bg2);height:var(--fh);margin-top:var(--gap)}
.funnel i{display:block;background:linear-gradient(180deg,#ff7a3c,#b3400a);border-radius:3px;width:var(--bw)}
.badge{display:inline-block;border:2px solid #ff7a3c;color:#ff7a3c;border-radius:100px;
  padding:var(--bp);font-size:var(--bf);font-weight:800;letter-spacing:.06em;
  text-transform:uppercase;margin-top:var(--gap)}
"""

FUNNEL = "".join(f'<i style="height:{h}%"></i>' for h in (100, 78, 55, 38, 24, 14))


def page(vars_, body):
    v = ";".join(f"{k}:{x}" for k, x in vars_.items())
    return f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}\nbody{{{v}}}</style></head><body><div class='glow'></div>{body}</body></html>"


WIDE = dict((("--pad", "46px"), ("--eb", "15px"), ("--h1", "72px"), ("--sub", "23px"),
             ("--gap", "22px"), ("--gap2", "16px"), ("--subw", "680px"), ("--rw", "78px"),
             ("--fg", "16px"), ("--fp", "20px"), ("--ft", "14px"), ("--fh", "38px"),
             ("--bw", "22px"), ("--bg2", "7px"), ("--bp", "11px 22px"), ("--bf", "17px")))

SQ = dict((("--pad", "84px"), ("--eb", "19px"), ("--h1", "104px"), ("--sub", "30px"),
           ("--gap", "34px"), ("--gap2", "24px"), ("--subw", "860px"), ("--rw", "100px"),
           ("--fg", "22px"), ("--fp", "30px"), ("--ft", "18px"), ("--fh", "92px"),
           ("--bw", "38px"), ("--bg2", "11px"), ("--bp", "14px 28px"), ("--bf", "22px")))

BAN = dict((("--pad", "42px"), ("--eb", "14px"), ("--h1", "56px"), ("--sub", "20px"),
            ("--gap", "16px"), ("--gap2", "12px"), ("--subw", "900px"), ("--rw", "70px"),
            ("--fg", "16px"), ("--fp", "16px"), ("--ft", "13px"), ("--fh", "44px"),
            ("--bw", "20px"), ("--bg2", "6px"), ("--bp", "10px 20px"), ("--bf", "16px")))

ENGINE_TOP = """<div class='pad'>
  <div class='eyebrow'>For online fitness coaches</div>
  <h1>The Booked<br>Call Engine</h1>
  <div class='rule'></div>
  <div class='sub'>The whole build &mdash; the offer, both funnels, every setting, the scripts, and the follow-up that makes people turn up.</div>
</div>"""

ENGINE_FOOT = f"""<div class='pad'>
  <div class='funnel'>{FUNNEL}</div>
  <div class='foot' style='margin-top:14px'><b>48 pages</b><span class='dot'></span><b>16 sections</b><span class='dot'></span><b>Both funnels</b></div>
</div>"""

BUNDLE_TOP = """<div class='pad'>
  <div class='eyebrow'>For online fitness coaches</div>
  <h1>Engine<br>+ 1:1 Hour</h1>
  <div class='rule'></div>
  <div class='sub'>Everything in the Engine, plus sixty minutes with me &mdash; we build your campaign live on the call.</div>
</div>"""

BUNDLE_FOOT = """<div class='pad'>
  <div class='badge'>You leave with it running</div>
  <div class='foot' style='margin-top:14px'><b>48 pages</b><span class='dot'></span><b>60 minutes</b><span class='dot'></span><b>Recording kept</b></div>
</div>"""

BANNER = f"""<div class='pad'>
  <div class='eyebrow'>Brent Chabassol</div>
  <h1>The Booked Call Engine</h1>
  <div class='sub'>Meta ads for fitness coaches. Know exactly what a booked call costs you.</div>
</div>
<div class='pad'><div class='foot'><b>Offer</b><span class='dot'></span><b>Funnels</b><span class='dot'></span><b>Scripts</b><span class='dot'></span><b>Follow-up</b></div></div>"""

JOBS = [
    ("engine-cover-16x9", 1200, 675, page(WIDE, ENGINE_TOP + ENGINE_FOOT)),
    ("engine-cover-square", 1080, 1080, page(SQ, ENGINE_TOP + ENGINE_FOOT)),
    ("bundle-cover-16x9", 1200, 675, page(WIDE, BUNDLE_TOP + BUNDLE_FOOT)),
    ("bundle-cover-square", 1080, 1080, page(SQ, BUNDLE_TOP + BUNDLE_FOOT)),
    ("storefront-banner", 1600, 400, page(BAN, BANNER)),
]

for name, w, h, html in JOBS:
    src = f"/tmp/claude-0/-home-user-daily-stock-reports/4e2650dc-a4c7-54b4-be63-99d3a7bed782/scratchpad/_{name}.html"
    open(src, "w").write(html)
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-sandbox",
                    "--hide-scrollbars", "--force-device-scale-factor=2",
                    f"--window-size={w},{h}", f"--screenshot={OUT/name}.png", src],
                   capture_output=True)
    sz = (OUT / f"{name}.png").stat().st_size // 1024
    print(f"{name}.png  {w}x{h} @2x  {sz}KB")
