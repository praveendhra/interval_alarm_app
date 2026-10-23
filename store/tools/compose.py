import sys, base64, pathlib, subprocess
shots=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2]); out.mkdir(exist_ok=True)
def b64(p): return 'data:image/png;base64,'+base64.b64encode(pathlib.Path(p).read_bytes()).decode()
icon=b64('icon_1024.png')
slides=[
 ('01_home.png','Alarms that keep<br><span>the beat</span>','Ring every 30 minutes, every hour,<br>or any interval you like.'),
 ('03_create.png','Set it once.<br><span>Done all day.</span>','Pick a start, an end and how often.<br>Cadence handles every ring between.'),
 ('02_detail.png','A heads-up<br><span>before each ring</span>','Soft reminders minutes ahead,<br>and a live timeline of what’s next.'),
 (None,'Private<br><span>by design</span>','No account. No ads. No tracking.<br>Everything stays on your iPhone.'),
]
CSS='''*{margin:0;box-sizing:border-box}html,body{width:1320px;height:2868px;overflow:hidden}
body{font-family:"Inter Display","Inter",sans-serif;color:#F1F5F9;
background:radial-gradient(120% 60% at 50% 0%,#24305A 0%,#111833 45%,#070A14 100%);position:relative}
.glow{position:absolute;width:1400px;height:1400px;left:-40px;top:1300px;border-radius:50%;
background:radial-gradient(circle,rgba(255,122,26,.35),rgba(255,122,26,0) 60%)}
h1{position:absolute;top:220px;left:0;right:0;text-align:center;font-size:118px;font-weight:800;letter-spacing:-4px;line-height:1.02}
h1 span{background:linear-gradient(100deg,#FF4D2E,#FF7A1A 55%,#FFC247);-webkit-background-clip:text;color:transparent}
p{position:absolute;top:520px;left:0;right:0;text-align:center;font-size:46px;line-height:1.35;color:#A9B4C8;font-weight:500}
.phone{position:absolute;left:170px;top:800px;width:980px;border-radius:120px;padding:22px;
background:linear-gradient(160deg,#3A4363,#151B2E 40%,#0B0F1C);box-shadow:0 60px 160px rgba(0,0,0,.6),0 0 0 2px rgba(255,255,255,.08)}
.phone img{display:block;width:100%;border-radius:100px}
.hero{position:absolute;left:0;right:0;top:880px;text-align:center}
.hero img{width:560px;border-radius:125px;box-shadow:0 50px 140px rgba(255,90,30,.35),0 0 0 2px rgba(255,255,255,.06)}
.chips{position:absolute;top:1650px;left:130px;right:130px;display:flex;flex-direction:column;gap:34px}
.chip{display:flex;align-items:center;gap:34px;padding:44px 52px;border-radius:44px;background:rgba(26,32,53,.85);border:2px solid #2A3150;font-size:48px;font-weight:600}
.dot{width:26px;height:26px;border-radius:50%;background:linear-gradient(135deg,#FF4D2E,#FFC247);flex:none}
'''
for i,(shot,h,sub) in enumerate(slides,1):
    if shot:
        body=f'<div class="glow"></div><h1>{h}</h1><p>{sub}</p><div class="phone"><img src="{b64(shots/shot)}"></div>'
    else:
        chips=''.join(f'<div class="chip"><div class="dot"></div>{t}</div>' for t in ('No sign-up, ever','Alarms stored only on your phone','Your own tunes, kept private'))
        body=f'<div class="glow"></div><h1>{h}</h1><p>{sub}</p><div class="hero"><img src="{icon}"></div><div class="chips">{chips}</div>'
    html=out/f'slide{i}.html'
    html.write_text(f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{body}</body></html>')
    subprocess.run([sys.executable,'render.py',str(html),str(out/f'{i:02d}.png'),'1320','2868'],check=True)
print('ok')
