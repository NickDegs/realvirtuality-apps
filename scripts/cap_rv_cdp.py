#!/usr/bin/env python3
# RV gerçek ekranlar — CDP device-metrics ile TAM App Store boyutu (1290x2796 / 1242x2688).
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from pathlib import Path
import time, base64
LANGS=["tr","en","de","fr","es","ar","ru"]
LOC={"tr":"tr-TR","en":"en-US","de":"de-DE","fr":"fr-FR","es":"es-ES","ar":"ar-SA","ru":"ru"}
# dir-adı : (cssW, cssH) @3x → 6.9 dir=1290x2796(APP_IPHONE_67), 6.5 dir=1242x2688(APP_IPHONE_65)
SIZES={"6.9":(430,932), "6.5":(414,896)}
TOOL_IDX=[0,3,20,17]
OUT=Path("/tmp/rv_real/realvirtuality-ai")
def nd(w,h):
    o=Options()
    for a in ["--headless=new","--disable-gpu","--no-sandbox","--hide-scrollbars"]: o.add_argument(a)
    dd=webdriver.Chrome(options=o)
    dd.execute_cdp_cmd("Emulation.setDeviceMetricsOverride",{"width":w,"height":h,"deviceScaleFactor":3,"mobile":True})
    dd.set_page_load_timeout(40); return dd
def shot(d,path):
    res=d.execute_cdp_cmd("Page.captureScreenshot",{"format":"png","captureBeyondViewport":False})
    open(path,"wb").write(base64.b64decode(res["data"]))
def clean(d):
    d.execute_script("['#ndw-b','[id^=ndw-]','[class*=ndw]'].forEach(s=>document.querySelectorAll(s).forEach(e=>e.style.display='none'));document.querySelectorAll('iframe').forEach(e=>e.style.display='none');")
def setlang(d,code):
    d.execute_script("var s=document.getElementById('lang');if(s){s.value=arguments[0];s.dispatchEvent(new Event('change',{bubbles:true}));}",code); time.sleep(2.5)
def scroll_tool(d,n,off=110):
    d.execute_script("""var n=arguments[0],off=arguments[1];let cards=[];document.querySelectorAll('h3').forEach(h=>{let c=h.parentElement;for(let i=0;i<4&&c;i++){if(c.querySelector('button')){break;}c=c.parentElement;}if(c&&!cards.includes(c))cards.push(c);});var card=cards[n];if(card)window.scrollTo(0,card.getBoundingClientRect().top+window.scrollY-off);""",n,off); time.sleep(0.7)
def scroll_credits(d,off=90):
    d.execute_script("""var off=arguments[0];let best=null,bt=1e9;document.querySelectorAll('h1,h2,h3,div,span,p').forEach(e=>{var t=(e.innerText||'');if(/[€₺$]\\s?\\d/.test(t)&&e.offsetHeight>0&&e.offsetHeight<400){var top=e.getBoundingClientRect().top+window.scrollY;if(top<bt){bt=top;best=e;}}});if(best)window.scrollTo(0,bt-off-140);""",off); time.sleep(0.7)
def run():
    tot=0
    for size,(w,h) in SIZES.items():
        d=nd(w,h)
        try:
            d.get("https://realvirtuality.app"); time.sleep(4.5)
            for lc,loc in LOC.items():
                setlang(d,lc); clean(d)
                od=OUT/loc/size; od.mkdir(parents=True,exist_ok=True)
                d.execute_script("window.scrollTo(0,0)"); time.sleep(0.5); clean(d); shot(d,str(od/"01_hero.png"))
                for i,idx in enumerate(TOOL_IDX):
                    scroll_tool(d,idx); clean(d); shot(d,str(od/f"0{i+2}_tool{idx}.png"))
                scroll_credits(d); clean(d); shot(d,str(od/"06_credits.png"))
                tot+=6; print(f"OK {loc}/{size}",flush=True)
        finally: d.quit()
    print("=== BİTTİ",tot,"===")
run()
