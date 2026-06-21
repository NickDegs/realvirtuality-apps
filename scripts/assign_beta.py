#!/usr/bin/env python3
# Build'i upload sonrası tüm beta gruplarına otomatik atar (yoksa TestFlight'ta görünmez!).
# Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER, ASC_APP_ID
import os, sys, time, json, urllib.request, urllib.error
try:
    import jwt
except ImportError:
    os.system(sys.executable + " -m pip install -q --break-system-packages pyjwt cryptography 2>/dev/null"
              " || " + sys.executable + " -m pip install -q --user pyjwt cryptography")
    import site, importlib; importlib.reload(site)
    import jwt
KEY_ID=os.environ["ASC_KEY_ID"]; ISS=os.environ["ASC_ISSUER"]; APP=os.environ["ASC_APP_ID"]
KEY=open(os.environ["ASC_KEY_PATH"]).read()
def tok():
    now=int(time.time())
    return jwt.encode({"iss":ISS,"iat":now,"exp":now+1000,"aud":"appstoreconnect-v1"},KEY,
                      algorithm="ES256",headers={"kid":KEY_ID,"typ":"JWT"})
def api(path, method="GET", body=None):
    data=json.dumps(body).encode() if body is not None else None
    r=urllib.request.Request("https://api.appstoreconnect.apple.com"+path, data=data, method=method,
        headers={"Authorization":"Bearer "+tok(),"Content-Type":"application/json"})
    try:
        resp=urllib.request.urlopen(r, timeout=40); raw=resp.read()
        return {"_ok":resp.status} if not raw else json.loads(raw)
    except urllib.error.HTTPError as e:
        return {"_err":e.code,"_body":e.read().decode()[:400]}
# En yeni build VALID olana kadar bekle (işlem süresi)
bid=None
for _ in range(40):  # ~20 dk
    d=api(f"/v1/builds?filter[app]={APP}&limit=1&sort=-uploadedDate")
    items=d.get("data") or []
    if items:
        a=items[0]["attributes"]; st=a.get("processingState")
        print("build v%s islem=%s"%(a.get("version"),st), flush=True)
        if st=="VALID": bid=items[0]["id"]; break
    time.sleep(30)
if not bid:
    print("⚠️ build VALID olmadı, atama atlandı"); sys.exit(0)
bg=api(f"/v1/apps/{APP}/betaGroups")
for g in bg.get("data",[]):
    gid=g["id"]; name=g["attributes"].get("name")
    r=api(f"/v1/betaGroups/{gid}/relationships/builds","POST",{"data":[{"type":"builds","id":bid}]})
    print(f"  → '{name}': {r}")
print("✅ build tüm gruplara atandı")
