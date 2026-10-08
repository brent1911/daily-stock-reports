"""Build the installable web-app version of the guide from the print source."""
import re, json, pathlib, subprocess

HERE = pathlib.Path(__file__).parent
APP = HERE / "app"
APP.mkdir(exist_ok=True)
CHROME = "/opt/pw-browsers/chromium"

src = (HERE / "index.html").read_text()
sections = re.findall(r"<section>.*?</section>", src, re.S)
assert len(sections) == 16, len(sections)

titles = []
for s in sections:
    t = re.search(r"<h2>(.*?)</h2>", s, re.S).group(1)
    titles.append(re.sub(r"<[^>]+>", "", t).strip())

def strip_sechead(html):
    """Remove the <div class="sechead"> block by balancing div tags, and
    return (remaining_html, lede_html). A lazy regex here swallows real
    content, because sechead contains a nested div."""
    start = html.find('<div class="sechead">')
    if start == -1:
        return html, ""
    depth, k = 0, start
    tag = re.compile(r"<(/?)div\b", re.I)
    while k < len(html):
        m = tag.search(html, k)
        if not m:
            break
        depth += -1 if m.group(1) else 1
        k = m.end()
        if depth == 0:
            end = html.find(">", k) + 1
            head = html[start:end]
            lede = re.search(r'<p class="lede">(.*?)</p>', head, re.S)
            return html[:start] + html[end:], (lede.group(1).strip() if lede else "")
    return html, ""

bodies, ledes = [], []
for s in sections:
    b, lede = strip_sechead(s)
    b = re.sub(r"</?section>", "", b)
    bodies.append(b.strip())
    ledes.append(lede)

CSS = """
:root{--ink:#16181d;--mid:#434a59;--mute:#6b7280;--line:#e4e7ec;--bg:#fff;--bg2:#f6f7f9;
 --bg3:#fffaf4;--acc:#b3400a;--acc2:#0d5c63;--ok:#15803d;
 --sans:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
 --serif:"Charter","Bitstream Charter",Georgia,serif;--top:54px;--bot:62px}
@media(prefers-color-scheme:dark){:root{--ink:#eceef2;--mid:#b9bfca;--mute:#8b93a3;--line:#2a2f3a;
 --bg:#101217;--bg2:#171a21;--bg3:#1d1813;--acc:#ff8a4c;--acc2:#5bc8d1;--ok:#4ade80}}
*{box-sizing:border-box}
html,body{margin:0;overflow-x:hidden;max-width:100%;-webkit-text-size-adjust:100%}
body{background:var(--bg);color:var(--ink);font-family:var(--serif);font-size:17.5px;
 line-height:1.6;-webkit-font-smoothing:antialiased;
 padding:calc(var(--top) + env(safe-area-inset-top)) 0 calc(var(--bot) + env(safe-area-inset-bottom))}
h1,h2,h3,h4,.ui,button,nav{font-family:var(--sans)}
.wrap{max-width:620px;margin:0 auto;padding:0 20px}

/* chrome */
.bar{position:fixed;left:0;right:0;z-index:40;background:var(--bg);border-color:var(--line)}
#top{top:0;height:calc(var(--top) + env(safe-area-inset-top));padding-top:env(safe-area-inset-top);
 border-bottom:1px solid var(--line);display:flex;align-items:center;gap:10px;padding-inline:14px}
#top .t{font-size:14px;font-weight:700;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
#top .n{font-size:11px;color:var(--mute);font-weight:700;letter-spacing:.08em}
#bot{bottom:0;height:calc(var(--bot) + env(safe-area-inset-bottom));padding-bottom:env(safe-area-inset-bottom);
 border-top:1px solid var(--line);display:flex;align-items:center;gap:8px;padding-inline:12px}
.ico{width:42px;height:42px;min-width:42px;border-radius:9px;border:1px solid var(--line);
 background:var(--bg2);color:var(--ink);font-size:18px;display:flex;align-items:center;
 justify-content:center;cursor:pointer}
.ico[disabled]{opacity:.35}
#bot .mid{flex:1;text-align:center;font-size:12px;color:var(--mute);font-weight:700}
.prog{position:absolute;top:0;left:0;height:2px;background:var(--acc);transition:width .25s}

/* menu */
#menu{position:fixed;inset:0;z-index:50;background:var(--bg);overflow-y:auto;
 padding:calc(18px + env(safe-area-inset-top)) 0 40px;display:none}
#menu.on{display:block}
#menu h2{font-size:20px;margin:0 0 4px}
.mrow{display:flex;gap:12px;align-items:baseline;padding:13px 0;border-bottom:1px solid var(--line);
 cursor:pointer;font-family:var(--sans)}
.mrow .i{font-size:12px;font-weight:800;color:var(--acc);min-width:24px}
.mrow .x{font-size:15.5px;font-weight:700}
.mrow.cur .x{color:var(--acc)}
.mrow .d{display:block;font-size:13px;color:var(--mute);font-weight:400;margin-top:2px}

/* content */
h2.sh{font-size:clamp(23px,6vw,29px);line-height:1.15;letter-spacing:-.025em;margin:4px 0 6px;font-weight:800}
.kick{font-family:var(--sans);font-size:11px;letter-spacing:.17em;text-transform:uppercase;
 color:var(--acc);font-weight:700}
.lede{font-size:17.5px;color:var(--mid);margin:10px 0 22px}
h3{font-size:18px;margin:26px 0 8px;font-weight:800;letter-spacing:-.012em}
h4{font-size:12.5px;margin:22px 0 7px;text-transform:uppercase;letter-spacing:.09em;color:var(--acc2);font-weight:800}
p{margin:0 0 14px}
ul,ol{margin:0 0 14px;padding-left:21px}li{margin-bottom:8px}
table{width:100%;border-collapse:collapse;margin:16px 0;font-family:var(--sans);font-size:14px;display:block;overflow-x:auto}
th{text-align:left;background:var(--ink);color:var(--bg);padding:9px 10px;font-size:11px;
 text-transform:uppercase;letter-spacing:.06em;font-weight:800;white-space:nowrap}
td{padding:9px 10px;border-bottom:1px solid var(--line);vertical-align:top}
.script{background:var(--bg2);border:1px solid var(--line);border-left:3px solid var(--acc2);
 padding:15px 16px;margin:16px 0;border-radius:0 9px 9px 0}
.script .lbl{font-family:var(--sans);font-size:10.5px;text-transform:uppercase;letter-spacing:.13em;
 color:var(--acc2);font-weight:800;margin-bottom:9px}
.script p{margin:0 0 9px;font-size:16.5px}.script p:last-child{margin:0}
.fill{background:#ffe9d4;border-bottom:1px solid var(--acc);padding:0 3px;border-radius:2px;
 font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13.5px;font-weight:700;color:#8a2f06}
@media(prefers-color-scheme:dark){.fill{background:#3a2415;color:#ffb184;border-color:#8a4a24}}
.eg{font-size:15.5px;color:var(--mute);font-style:italic;margin-top:10px;padding-top:10px;border-top:1px dashed var(--line)}
.box{background:var(--bg3);border:1px solid var(--line);border-left:3px solid var(--acc);
 padding:15px 16px;margin:16px 0;border-radius:0 9px 9px 0}
.box .lbl{font-family:var(--sans);font-size:10.5px;text-transform:uppercase;letter-spacing:.13em;
 color:var(--acc);font-weight:800;margin-bottom:8px}
.box p:last-child{margin:0}
.rule{background:var(--bg2);border-left:3px solid var(--acc2);padding:13px 15px;margin:16px 0;
 font-family:var(--sans);font-size:15.5px;border-radius:0 9px 9px 0}
blockquote{border-left:3px solid var(--acc);background:var(--bg3);margin:16px 0;padding:14px 16px;border-radius:0 9px 9px 0}
blockquote p:last-child{margin:0}
.formula{background:var(--ink);color:var(--bg);padding:17px;margin:16px 0;text-align:center;
 font-family:var(--sans);font-size:16px;font-weight:800;border-radius:10px}
.kpi{display:flex;gap:9px;margin:16px 0}
.kpi div{flex:1;background:var(--bg2);border-top:2.5px solid var(--acc2);padding:12px 10px;border-radius:0 0 8px 8px}
.kpi .k{font-family:var(--sans);font-size:19px;font-weight:800}
.kpi .v{font-family:var(--sans);font-size:9.5px;color:var(--mute);text-transform:uppercase;letter-spacing:.07em;margin-top:3px}
.chk{list-style:none;padding:0;font-family:var(--sans);font-size:15.5px}
.chk li{display:flex;gap:11px;padding:11px 0;border-bottom:1px solid var(--line);margin:0;cursor:pointer}
.chk li::before{content:"";display:inline-block;min-width:21px;height:21px;margin-top:1px;
 border:1.6px solid var(--mid);border-radius:5px}
.chk li.done{color:var(--mute)}
.chk li.done::before{content:"✓";background:var(--ok);border-color:var(--ok);color:#fff;
 font-weight:800;text-align:center;line-height:19px;font-size:14px}
.nb{font-size:15.5px;color:var(--mute);font-style:italic}
.end{border-top:2px solid var(--ink);margin-top:26px;padding-top:14px;font-family:var(--sans);font-size:14px;color:var(--mute)}

/* install */
#ins{position:fixed;inset:0;z-index:60;background:rgba(0,0,0,.55);display:none;
 align-items:flex-end;justify-content:center}
#ins.on{display:flex}
#ins .card{background:var(--bg);width:100%;max-width:520px;border-radius:16px 16px 0 0;
 padding:24px 22px calc(26px + env(safe-area-inset-bottom))}
#ins h3{margin:0 0 10px}
#ins ol{padding-left:19px}
#ins .close{width:100%;margin-top:14px;background:var(--acc);color:#fff;border:0;border-radius:9px;
 padding:15px;font-size:16px;font-weight:700;min-height:52px;cursor:pointer}
.ghost{background:none;border:0;color:var(--mute);font-family:var(--sans);font-size:13px;
 text-decoration:underline;cursor:pointer;padding:0}
"""

APP_JS = """
var S = __SECTIONS__, T = __TITLES__, D = __DESCS__, L = __LEDES__;
var i = 0, body = document.getElementById('body'), menu = document.getElementById('menu');

function key(n){ return 'bce_chk_' + n; }

function render(n, keepScroll){
  i = Math.max(0, Math.min(S.length - 1, n));
  body.innerHTML = '<div class="wrap"><div class="kick">Section ' + String(i+1).padStart(2,'0') +
    '</div><h2 class="sh">' + T[i] + '</h2>' +
    (L[i] ? '<p class="lede">' + L[i] + '</p>' : '') + S[i] + '</div>';
  document.getElementById('ttl').textContent = T[i];
  document.getElementById('num').textContent = String(i+1).padStart(2,'0') + '/16';
  document.getElementById('pos').textContent = 'Section ' + (i+1) + ' of 16';
  document.getElementById('prev').disabled = i === 0;
  document.getElementById('next').disabled = i === S.length - 1;
  document.getElementById('prog').style.width = ((i+1)/S.length*100) + '%';
  try { localStorage.setItem('bce_at', i); } catch(e){}
  if (!keepScroll) window.scrollTo(0,0);
  wireChecks();
  [].forEach.call(document.querySelectorAll('.mrow'), function(r,x){
    r.classList.toggle('cur', x === i);
  });
}

function wireChecks(){
  [].forEach.call(body.querySelectorAll('.chk li'), function(li, x){
    var k = key(i + '_' + x);
    try { if (localStorage.getItem(k) === '1') li.classList.add('done'); } catch(e){}
    li.addEventListener('click', function(){
      li.classList.toggle('done');
      try { localStorage.setItem(k, li.classList.contains('done') ? '1' : '0'); } catch(e){}
    });
  });
}

// menu
var mw = document.getElementById('mlist');
mw.innerHTML = T.map(function(t,x){
  return '<div class="mrow" data-i="' + x + '"><span class="i">' +
    String(x+1).padStart(2,'0') + '</span><span class="x">' + t +
    '<span class="d">' + D[x] + '</span></span></div>';
}).join('');
mw.addEventListener('click', function(e){
  var r = e.target.closest('.mrow'); if (!r) return;
  menu.classList.remove('on'); render(+r.dataset.i);
});
document.getElementById('burger').onclick = function(){ menu.classList.add('on'); };
document.getElementById('mclose').onclick = function(){ menu.classList.remove('on'); };
document.getElementById('prev').onclick = function(){ render(i-1); };
document.getElementById('next').onclick = function(){ render(i+1); };

document.addEventListener('keydown', function(e){
  if (e.key === 'ArrowLeft') render(i-1);
  if (e.key === 'ArrowRight') render(i+1);
});

// install prompt
var deferred = null;
window.addEventListener('beforeinstallprompt', function(e){
  e.preventDefault(); deferred = e;
  document.getElementById('installBtn').style.display = 'block';
});
function isStandalone(){
  return window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
}
document.getElementById('installBtn').onclick = function(){
  if (deferred){ deferred.prompt(); deferred = null; return; }
  var ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
  document.getElementById('insBody').innerHTML = ios
    ? '<ol><li>Tap the <strong>Share</strong> button at the bottom of Safari</li><li>Scroll down and tap <strong>Add to Home Screen</strong></li><li>Tap <strong>Add</strong></li></ol><p class="nb">It opens like an app after that, and works without signal.</p>'
    : '<ol><li>Open the browser menu <strong>(⋮)</strong></li><li>Tap <strong>Install app</strong> or <strong>Add to Home screen</strong></li><li>Confirm</li></ol><p class="nb">It opens like an app after that, and works without signal.</p>';
  document.getElementById('ins').classList.add('on');
};
document.getElementById('insClose').onclick = function(){
  document.getElementById('ins').classList.remove('on');
};
if (isStandalone()) document.getElementById('installBtn').style.display = 'none';

var at = 0;
try { at = parseInt(localStorage.getItem('bce_at') || '0', 10) || 0; } catch(e){}
render(at);

if ('serviceWorker' in navigator)
  navigator.serviceWorker.register('sw.js').catch(function(){});
"""

descs = [
    "Eight fill-in parts, assembled into one offer statement",
    "The arithmetic, and the go/no-go before you spend",
    "DM or call funnel, on real costs and budgets",
    "Every setting, field by field",
    "Five installs, each with the test that proves it",
    "Six fill-in frameworks and compliance rewrites",
    "What to film, the specs, the testimonial interview",
    "Exact launch settings at $20/day",
    "First reply to booked call, every branch",
    "Budget floor, optimisation event, retargeting",
    "Page structure, headline formulas, video script, form",
    "The settings that quietly lose a third of your calls",
    "Seven touches, with the copy for each",
    "Symptom to fix, scale triggers, kill criteria",
    "Four numbers, and what to ignore",
    "Twenty things that break, and the fix",
]

js = (APP_JS.replace("__SECTIONS__", json.dumps(bodies))
            .replace("__TITLES__", json.dumps(titles))
            .replace("__DESCS__", json.dumps(descs))
            .replace("__LEDES__", json.dumps(ledes)))

html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,maximum-scale=5">
<title>The Booked Call Engine</title>
<link rel="manifest" href="manifest.json">
<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme:light)">
<meta name="theme-color" content="#101217" media="(prefers-color-scheme:dark)">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="apple-mobile-web-app-title" content="Booked Call">
<link rel="apple-touch-icon" href="icon-180.png">
<link rel="icon" href="icon-192.png">
<style>{CSS}</style>
</head>
<body>

<div class="bar" id="top">
  <button class="ico" id="burger" aria-label="Sections">☰</button>
  <span class="t" id="ttl"></span>
  <span class="n" id="num"></span>
  <div class="prog" id="prog"></div>
</div>

<main id="body"></main>

<div class="bar" id="bot">
  <button class="ico" id="prev" aria-label="Previous section">‹</button>
  <span class="mid" id="pos"></span>
  <button class="ico" id="next" aria-label="Next section">›</button>
</div>

<div id="menu">
  <div class="wrap">
    <h2>The Booked Call Engine</h2>
    <p class="nb" style="margin:0 0 6px">16 sections. Tap to jump.</p>
    <div id="mlist"></div>
    <button id="installBtn" style="display:none;width:100%;margin:20px 0 10px;background:var(--acc);
      color:#fff;border:0;border-radius:9px;padding:15px;font-size:16px;font-weight:700;min-height:52px;
      cursor:pointer;font-family:var(--sans)">Add to home screen</button>
    <button class="ghost" id="mclose" style="margin-top:14px">Close</button>
  </div>
</div>

<div id="ins">
  <div class="card">
    <h3>Keep it on your home screen</h3>
    <div id="insBody"></div>
    <button class="close" id="insClose">Got it</button>
  </div>
</div>

<script>{js}</script>
</body>
</html>"""

(APP / "index.html").write_text(html)

manifest = {
    "name": "The Booked Call Engine",
    "short_name": "Booked Call",
    "description": "Build a Meta ads funnel that books calls, and know what each one costs.",
    "start_url": "./index.html",
    "scope": "./",
    "display": "standalone",
    "orientation": "portrait",
    "background_color": "#101217",
    "theme_color": "#101217",
    "icons": [
        {"src": "icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any"},
        {"src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any"},
        {"src": "icon-maskable.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
    ],
}
(APP / "manifest.json").write_text(json.dumps(manifest, indent=2))

(APP / "sw.js").write_text("""
var C = 'bce-v1';
var FILES = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png'];
self.addEventListener('install', function(e){
  self.skipWaiting();
  e.waitUntil(caches.open(C).then(function(c){ return c.addAll(FILES); }).catch(function(){}));
});
self.addEventListener('activate', function(e){
  e.waitUntil(caches.keys().then(function(k){
    return Promise.all(k.filter(function(n){ return n !== C; }).map(function(n){ return caches.delete(n); }));
  }));
  self.clients.claim();
});
self.addEventListener('fetch', function(e){
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(function(hit){
      return hit || fetch(e.request).then(function(r){
        var copy = r.clone();
        caches.open(C).then(function(c){ c.put(e.request, copy); }).catch(function(){});
        return r;
      }).catch(function(){ return caches.match('./index.html'); });
    })
  );
});
""".strip())

# icons
ICON = """<!doctype html><html><head><meta charset='utf-8'><style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{width:{s}px;height:{s}px;background:#0e1014;display:flex;align-items:center;
justify-content:center}}
.b{{display:flex;align-items:flex-end;gap:{g}px;height:{h}px}}
.b i{{display:block;width:{w}px;border-radius:{r}px;background:linear-gradient(180deg,#ff9057,#c2440a)}}
</style></head><body><div class='b'>{bars}</div></body></html>"""

for name, size, frac in [("icon-192", 192, .50), ("icon-512", 512, .50),
                         ("icon-180", 180, .50), ("icon-maskable", 512, .38)]:
    h = int(size * frac)
    w = int(h * 0.26)
    g = max(3, int(w * 0.40))
    bars = "".join(f"<i style='height:{hh}%'></i>" for hh in (100, 74, 50))
    p = ICON.format(s=size, g=g, h=h, w=w, r=max(2, w // 5), bars=bars)
    f = HERE / f"_icon_{name}.html"
    f.write_text(p)
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
                    f"--window-size={size},{size}", f"--screenshot={APP/name}.png", str(f)],
                   capture_output=True)
    f.unlink()
    print(f"{name}.png {size}x{size}")

print("app built:", len(bodies), "sections ->", APP / "index.html")
