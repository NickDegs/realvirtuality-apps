#!/usr/bin/env python3
# App Store incelemeye gönder: mevcut review varsa iptal, yeni build bağla, notları ekle, gönder.
# Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER, ASC_APP_ID, REVIEW_NOTES (opsiyonel), WHATS_NEW (opsiyonel)
import os, sys, time, json, urllib.request, urllib.error
try:
    import jwt
except ImportError:
    os.system(sys.executable + " -m pip install -q --break-system-packages pyjwt cryptography 2>/dev/null"
              " || " + sys.executable + " -m pip install -q --user pyjwt cryptography")
    import site, importlib; importlib.reload(site); import jwt

KEY_ID  = os.environ["ASC_KEY_ID"]
ISS     = os.environ["ASC_ISSUER"]
APP     = os.environ["ASC_APP_ID"]
KEY     = open(os.environ["ASC_KEY_PATH"]).read()
REVIEW_NOTES = os.environ.get("REVIEW_NOTES", "")
WHATS_NEW    = os.environ.get("WHATS_NEW", "Bug fixes and stability improvements.")

def tok():
    now = int(time.time())
    return jwt.encode({"iss": ISS, "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"},
                      KEY, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})

def api(path, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        "https://api.appstoreconnect.apple.com" + path, data=data, method=method,
        headers={"Authorization": "Bearer " + tok(), "Content-Type": "application/json"})
    try:
        resp = urllib.request.urlopen(req, timeout=40)
        raw = resp.read()
        return {"_ok": resp.status} if not raw else json.loads(raw)
    except urllib.error.HTTPError as e:
        return {"_err": e.code, "_body": e.read().decode()[:600]}

# ── 1) En yeni build VALID olana kadar bekle ──────────────────────────────────
print("⏳ Build bekleniyor…", flush=True)
bid = None
for attempt in range(50):   # ~25 dk
    d = api(f"/v1/builds?filter[app]={APP}&limit=1&sort=-uploadedDate")
    items = d.get("data") or []
    if items:
        attrs = items[0]["attributes"]
        st = attrs.get("processingState")
        ver = attrs.get("version")
        print(f"  build v{ver} → {st}", flush=True)
        if st == "VALID":
            bid = items[0]["id"]; break
        if st in ("FAILED", "INVALID"):
            print(f"❌ Build {st}, çıkılıyor."); sys.exit(1)
    time.sleep(30)

if not bid:
    print("❌ Build 25 dk içinde VALID olmadı."); sys.exit(1)
print(f"✅ Build VALID: {bid}")

# ── 2) PREPARE_FOR_SUBMISSION durumundaki versiyonu bul ───────────────────────
ver_id = None
for state in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "WAITING_FOR_REVIEW", "IN_REVIEW", "REJECTED", "READY_FOR_REVIEW"):
    d = api(f"/v1/apps/{APP}/appStoreVersions?filter[appStoreState]={state}&filter[platform]=IOS&limit=1")
    items = d.get("data") or []
    if items:
        ver_id = items[0]["id"]
        cur_state = items[0]["attributes"].get("appStoreState")
        print(f"📋 Versiyon bulundu: {ver_id} (durum={cur_state})")
        break

if not ver_id:
    print("❌ Gönderilecek aktif App Store versiyonu bulunamadı.")
    print("   App Store Connect'te yeni versiyon oluşturulmuş olmalı.")
    sys.exit(1)

# ── 3) WAITING_FOR_REVIEW veya IN_REVIEW ise review'ı iptal et ───────────────
if cur_state in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
    print(f"🔄 Mevcut review ({cur_state}) iptal ediliyor…")
    subs = api(f"/v1/appStoreVersions/{ver_id}/appStoreVersionSubmission")
    sub_items = subs.get("data") or []
    if isinstance(sub_items, dict):
        sub_items = [sub_items]
    if sub_items:
        sub_id = sub_items[0]["id"] if "id" in sub_items[0] else None
        if sub_id:
            r = api(f"/v1/appStoreVersionSubmissions/{sub_id}", method="DELETE")
            print(f"  İptal: {r}")
    # Direkt PATCH ile de dene (daha yeni API)
    r2 = api(f"/v1/appStoreVersions/{ver_id}", method="PATCH",
             body={"data": {"type": "appStoreVersions", "id": ver_id,
                            "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}}})
    time.sleep(5)
    cur_state = "PREPARE_FOR_SUBMISSION"

# ── 4) Build'i versiyona bağla ────────────────────────────────────────────────
print(f"🔗 Build {bid} → versiyon {ver_id} bağlanıyor…")
r = api(f"/v1/appStoreVersions/{ver_id}/relationships/build", method="PATCH",
        body={"data": {"type": "builds", "id": bid}})
print(f"  Bağlantı: {r.get('_ok') or r.get('_err') or 'ok'}")

# ── 5) Reviewer notları + What's New ekle ────────────────────────────────────
if REVIEW_NOTES:
    print("📝 Reviewer notları ekleniyor…")
    # appReviewInformation oluştur/güncelle
    ari = api(f"/v1/appStoreVersions/{ver_id}/appReviewInformation")
    ari_items = ari.get("data")
    if ari_items and isinstance(ari_items, dict):
        ari_id = ari_items.get("id")
        if ari_id:
            r = api(f"/v1/appReviewInformations/{ari_id}", method="PATCH",
                    body={"data": {"type": "appReviewInformations", "id": ari_id,
                                   "attributes": {"notesForReview": REVIEW_NOTES}}})
            print(f"  Review notu güncellendi: {r.get('_ok') or r.get('_err') or 'ok'}")
    else:
        r = api("/v1/appReviewInformations", method="POST",
                body={"data": {"type": "appReviewInformations",
                               "attributes": {"notesForReview": REVIEW_NOTES},
                               "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}}})
        print(f"  Review notu oluşturuldu: {r.get('_ok') or r.get('_err') or 'ok'}")

if WHATS_NEW:
    locs = api(f"/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
    for loc in (locs.get("data") or []):
        lid = loc["id"]
        r = api(f"/v1/appStoreVersionLocalizations/{lid}", method="PATCH",
                body={"data": {"type": "appStoreVersionLocalizations", "id": lid,
                               "attributes": {"whatsNew": WHATS_NEW}}})
        lang = loc["attributes"].get("locale")
        print(f"  What's New ({lang}): {r.get('_ok') or r.get('_err') or 'ok'}")

# ── 6) İncelemeye gönder ─────────────────────────────────────────────────────
print("🚀 App Store incelemeye gönderiliyor…")
r = api("/v1/appStoreVersionSubmissions", method="POST",
        body={"data": {"type": "appStoreVersionSubmissions",
                       "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}}})
if r.get("data") or r.get("_ok"):
    print("✅ İncelemeye gönderildi!")
else:
    print(f"⚠️ Gönderme sonucu: {r}")
