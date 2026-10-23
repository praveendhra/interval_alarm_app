import math
BG='''<defs>
<radialGradient id="bg" cx="50%" cy="38%" r="75%"><stop offset="0" stop-color="#1B2440"/><stop offset="0.6" stop-color="#0E1426"/><stop offset="1" stop-color="#070A14"/></radialGradient>
<linearGradient id="og" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#FF4D2E"/><stop offset="0.55" stop-color="#FF7A1A"/><stop offset="1" stop-color="#FFC247"/></linearGradient>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="22" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="40"/></filter>
</defs><rect width="1024" height="1024" fill="url(#bg)"/>'''
def pt(cx,cy,r,deg):
    a=math.radians(deg-90); return cx+r*math.cos(a), cy+r*math.sin(a)
def arc(cx,cy,r,a0,a1):
    x0,y0=pt(cx,cy,r,a0); x1,y1=pt(cx,cy,r,a1); large=1 if (a1-a0)%360>180 else 0
    return f'M{x0:.1f},{y0:.1f} A{r},{r} 0 {large} 1 {x1:.1f},{y1:.1f}'
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{BG}{body}</svg>'

if __name__=="__main__":
  pass
# A: interval ring — gradient arc with beat dots
cx=cy=512; r=300
b='<circle cx="512" cy="512" r="300" fill="none" stroke="#FFFFFF" stroke-opacity="0.07" stroke-width="64"/>'
b+=f'<path d="{arc(cx,cy,r,0,270)}" fill="none" stroke="url(#og)" stroke-width="64" stroke-linecap="round" filter="url(#glow)"/>'
for d in (0,90,180,270):
    x,y=pt(cx,cy,r,d); b+=f'<circle cx="{x:.1f}" cy="{y:.1f}" r="20" fill="#FFF6E8"/>'
b+='<circle cx="512" cy="512" r="70" fill="url(#og)" filter="url(#glow)"/>'
open('A.svg','w').write(svg(b))

# B: rhythm bars in a ring — 12 ticks, lit progressively
b='<circle cx="512" cy="512" r="250" fill="#FF7A1A" opacity="0.18" filter="url(#soft)"/>'
for i in range(12):
    d=i*30; x0,y0=pt(cx,cy,230,d); x1,y1=pt(cx,cy,330,d)
    lit=i<=8
    op=0.35+0.65*(i/8) if lit else 0.12
    col='url(#og)' if lit else '#FFFFFF'
    w=46 if i%3==0 else 30
    b+=f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" stroke="{col}" stroke-opacity="{op:.2f}" stroke-width="{w}" stroke-linecap="round"/>'
x1,y1=pt(cx,cy,190,240)
b+=f'<line x1="512" y1="512" x2="{x1:.1f}" y2="{y1:.1f}" stroke="#FFF6E8" stroke-width="34" stroke-linecap="round"/>'
b+='<circle cx="512" cy="512" r="44" fill="url(#og)"/>'
open('B.svg','w').write(svg(b))

# C: concentric cadence arcs (C-shape) — three nested arcs, opening right, with pulse dot
b=''
for r_,w,op in ((330,58,1),(230,58,0.8),(130,58,0.6)):
    b+=f'<path d="{arc(cx,cy,r_,40,320)}" fill="none" stroke="url(#og)" stroke-opacity="{op}" stroke-width="{w}" stroke-linecap="round" filter="url(#glow)"/>'
b+='<circle cx="512" cy="512" r="40" fill="#FFF6E8"/>'
open('C.svg','w').write(svg(b))
