import sys, asyncio
from playwright.sync_api import sync_playwright
# usage: render.py in.(svg|html) out.png width height
inp,out,w,h=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4])
import pathlib
with sync_playwright() as p:
    b=p.chromium.launch()
    pg=b.new_page(viewport={'width':w,'height':h})
    pg.goto(pathlib.Path(inp).resolve().as_uri()); pg.wait_for_timeout(400)
    pg.screenshot(path=out, omit_background=False)
    b.close()
