#!/usr/bin/env python3
# App Store ekran görüntüleri için premium FLUX.1-dev arka planları (RunPod, RV backend altyapısı).
import json, base64, urllib.request, time, random, sys
from pathlib import Path

C = json.load(open("/opt/ai-studio/.conf.json"))
RP = C["runpod_key"]; EP = C["endpoints"]
OUT = Path("/tmp/flux_bg"); OUT.mkdir(parents=True, exist_ok=True)

def flux_wf(prompt, steps=28, w=768, h=1344):
    return {"5":{"class_type":"EmptyLatentImage","inputs":{"width":w,"height":h,"batch_size":1}},
     "6":{"class_type":"CLIPTextEncode","inputs":{"text":prompt[:800],"clip":["11",0]}},
     "7":{"class_type":"CLIPTextEncode","inputs":{"text":"","clip":["11",0]}},
     "8":{"class_type":"VAEDecode","inputs":{"samples":["13",0],"vae":["10",0]}},
     "9":{"class_type":"SaveImage","inputs":{"filename_prefix":"s","images":["8",0]}},
     "10":{"class_type":"VAELoader","inputs":{"vae_name":"ae.safetensors"}},
     "11":{"class_type":"DualCLIPLoader","inputs":{"clip_name1":"t5xxl_fp8_e4m3fn.safetensors","clip_name2":"clip_l.safetensors","type":"flux"}},
     "12":{"class_type":"UNETLoader","inputs":{"unet_name":"flux1-dev.safetensors","weight_dtype":"default"}},
     "22":{"class_type":"FluxGuidance","inputs":{"conditioning":["6",0],"guidance":3.5}},
     "13":{"class_type":"KSampler","inputs":{"seed":random.randint(1,2**31),"steps":steps,"cfg":1,"sampler_name":"euler","scheduler":"simple","denoise":1,"model":["12",0],"positive":["22",0],"negative":["7",0],"latent_image":["5",0]}}}

def rp_run(inp, timeout=300, tries=5):
    hdr = {"Authorization":"Bearer "+RP, "Content-Type":"application/json"}
    for _ in range(tries):
        try:
            jid = json.loads(urllib.request.urlopen(urllib.request.Request(
                "https://api.runpod.ai/v2/%s/run"%EP["image"],
                data=json.dumps({"input":inp}).encode(), headers=hdr), timeout=30).read()).get("id","")
        except Exception: jid=""
        if not jid: time.sleep(3); continue
        t0=time.time()
        while time.time()-t0 < timeout:
            time.sleep(3)
            try:
                s=json.loads(urllib.request.urlopen(urllib.request.Request(
                    "https://api.runpod.ai/v2/%s/status/%s"%(EP["image"],jid), headers=hdr), timeout=20).read())
            except Exception: continue
            st=s.get("status","")
            if st=="COMPLETED": return s.get("output")
            if st in ("FAILED","CANCELLED","TIMED_OUT"): break
        time.sleep(3)
    return None

# Premium, marka-temalı (indigo/mor), METİNSİZ, UI'SIZ arka planlar — üstüne temiz UI bindirilecek.
BASE = ("premium abstract background for a high-end business dashboard app, deep indigo and royal "
        "blue with subtle violet, soft glowing bokeh light orbs, elegant flowing geometric mesh "
        "gradient, luxury fintech aesthetic, dark navy base, cinematic depth, ultra clean, "
        "no text, no letters, no UI, no people, smooth, high detail, vertical 9:16")
VARIANTS = [
    BASE,
    BASE + ", warm subtle amber accent glow in lower area",
    BASE + ", emerald green subtle accent highlights",
    BASE + ", soft magenta and purple nebula glow",
    BASE + ", cool teal and blue depth, minimal",
]

def main():
    n = int(sys.argv[1]) if len(sys.argv)>1 else 5
    done=0
    for i in range(n):
        p = VARIANTS[i % len(VARIANTS)]
        out = rp_run({"workflow": flux_wf(p)})
        b64=""
        if out:
            imgs=(out or {}).get("images") or []
            b64=(imgs[0].get("data") if imgs and isinstance(imgs[0],dict) else "") or (out or {}).get("message","") or ""
            if b64.startswith("data:"): b64=b64.split(",",1)[1]
        if b64:
            (OUT/f"bg_{i}.png").write_bytes(base64.b64decode(b64))
            done+=1; print(f"OK bg_{i}.png", flush=True)
        else:
            print(f"BOŞ bg_{i}", flush=True)
    print(f"=== BİTTİ {done}/{n} ===", flush=True)

if __name__=="__main__":
    main()
