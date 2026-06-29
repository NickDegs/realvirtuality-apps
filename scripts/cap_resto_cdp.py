#!/usr/bin/env python3
# resto-sistem (8792) çok dilli — CDP tam boyut (1290x2796 / 1242x2688).
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from pathlib import Path
import time, base64
LANGS=["tr","en","de","fr","es","ar","ru","it","pt","ja","zh","hi"]
LOC={"tr":"tr-TR","en":"en-US","de":"de-DE","fr":"fr-FR","es":"es-ES","ar":"ar-SA","ru":"ru","it":"it","pt":"pt-BR","ja":"ja","zh":"zh-Hans","hi":"hi"}
SIZES={"6.9":(430,932), "6.5":(414,896)}
TABS=[("01_panel","dash"),("02_siparis","orders"),("03_menu","menu"),("04_qr","qr"),("05_ayarlar","ayar")]
OUT=Path("/tmp/biz_ml")
def nd(w,h):
    o=Options()
    for a in ["--headless=new","--disable-gpu","--no-sandbox","--hide-scrollbars"]: o.add_argument(a)
    dd=webdriver.Chrome(options=o)
    dd.execute_cdp_cmd("Emulation.setDeviceMetricsOverride",{"width":w,"height":h,"deviceScaleFactor":3,"mobile":True})
    dd.set_page_load_timeout(40); return dd
def shot(d,path):
    res=d.execute_cdp_cmd("Page.captureScreenshot",{"format":"png","captureBeyondViewport":False})
    open(path,"wb").write(base64.b64decode(res["data"]))
def hide_modal(d):
    d.execute_script("var o=document.getElementById('onb');if(o)o.style.display='none';var r=document.getElementById('realInfo');if(r)r.style.display='none';")
def wait_data(d,t=12):
    t0=time.time()
    while time.time()-t0<t:
        v=d.execute_script("var e=document.getElementById('k_rev');return e?e.textContent:'';")
        if v and any(c.isdigit() for c in v) and v.strip() not in ('₺0','0'): return True
        time.sleep(0.6)
    return False
def start(d):
    # PREMIUM KOYU tema (otel = lacivert+altın), krem/sarı kafe yerine.
    d.execute_script("try{onbT='otel';}catch(e){window.onbT='otel';}var i=document.getElementById('onbName');if(i){i.value='Grand Hotel';i.dispatchEvent(new Event('input',{bubbles:true}));}try{if(window.startDemo)startDemo();}catch(e){}")
    time.sleep(3.5)
    if not wait_data(d):
        for _ in range(2):
            d.refresh(); time.sleep(2.5)
            if wait_data(d): break
    hide_modal(d)
def cap_lang(w,h,lang,size):
    d=nd(w,h)
    try:
        # PUBLIC domain → linkler gerçek (nickdegs.com), localhost değil
        base="https://nickdegs.com/restoran/sistem/"
        url=base if lang=="tr" else f"{base}?lang={lang}"
        d.get(url); time.sleep(2.6); start(d)
        od=OUT/LOC[lang]/size; od.mkdir(parents=True,exist_ok=True)
        for fn,dv in TABS:
            d.execute_script("var b=document.querySelector('button[data-v=\"'+arguments[0]+'\"]');if(b)b.click();",dv)
            time.sleep(1.1); hide_modal(d); d.execute_script("window.scrollTo(0,0)"); time.sleep(0.4)
            shot(d,str(od/f"{fn}.png"))
        print(f"OK {LOC[lang]}/{size}",flush=True)
    finally: d.quit()
for size,(w,h) in SIZES.items():
    for lang in LANGS: cap_lang(w,h,lang,size)
print("=== BİTTİ ===")
