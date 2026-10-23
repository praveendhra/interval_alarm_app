import math
from icons import BG, pt, arc, svg
cx=cy=512; r=292
b=f'<circle cx="512" cy="512" r="{r}" fill="none" stroke="#FFFFFF" stroke-opacity="0.07" stroke-width="72"/>'
b+=f'<path d="{arc(cx,cy,r,0,270)}" fill="none" stroke="url(#og)" stroke-width="72" stroke-linecap="round" filter="url(#glow)"/>'
for d,rr in ((0,21),(90,21),(180,21)):
    x,y=pt(cx,cy,r,d); b+=f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rr}" fill="#FFF6E8" fill-opacity="0.9"/>'
x,y=pt(cx,cy,r,270); b+=f'<circle cx="{x:.1f}" cy="{y:.1f}" r="27" fill="#FFFFFF"/>'
b+='<circle cx="512" cy="512" r="118" fill="none" stroke="url(#og)" stroke-opacity="0.28" stroke-width="12"/>'
b+='<circle cx="512" cy="512" r="56" fill="url(#og)" filter="url(#glow)"/>'
open('final.svg','w').write(svg(b))
