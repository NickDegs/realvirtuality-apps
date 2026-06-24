#!/usr/bin/env python3
"""
App Store Connect Screenshot Uploader
- Eski screenshot'ları temizle
- Yeni üretilenleri yükle (tüm locale + device)
Env: ASC_KEY_P8, ASC_KEY_ID, ASC_ISSUER_ID, SS_DIR (screenshot dizini)
"""

import os, sys, time, json, hashlib, urllib.request, urllib.error, base64
from pathlib import Path

try:
    from cryptography.hazmat.primitives import serialization, hashes
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
except ImportError:
    os.system(f"{sys.executable} -m pip install -q --break-system-packages cryptography")
    from cryptography.hazmat.primitives import serialization, hashes
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

# ─── Env ──────────────────────────────────────────────────────────────────────
KEY_PEM   = os.environ.get("ASC_KEY_P8", "")        # .p8 içeriği (PEM)
KEY_ID    = os.environ.get("ASC_KEY_ID", "")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "")
SS_DIR    = Path(os.environ.get("SS_DIR", "/opt/mobil-uygulamalar/screenshots"))

if not KEY_PEM or not KEY_ID or not ISSUER_ID:
    print("❌ ASC_KEY_P8 / ASC_KEY_ID / ASC_ISSUER_ID env gerekli")
    sys.exit(1)

_privkey = serialization.load_pem_private_key(KEY_PEM.encode(), password=None)

# App ID'leri
APPS = {
    "panel":    "6782606941",
    "business": "6782595925",
    "rv":       "6782458951",
    # eski isimler de desteklenir (geriye uyumluluk)
    "nickdegs-panel":   "6782606941",
    "nickdegs-business":"6782595925",
    "realvirtuality-ai":"6782458951",
}

# Dizin adı → ASC locale
DIR_TO_LOCALE = {
    "tr-TR":"tr", "en-US":"en-US", "de-DE":"de-DE",
    "fr-FR":"fr-FR", "es-ES":"es-ES", "ar-SA":"ar-SA", "ru":"ru",
}

# Dizin adı → ASC displayType
SIZE_TO_DISPLAY = {
    "6.7":"APP_IPHONE_67",
    "6.5":"APP_IPHONE_65",
    "5.5":"APP_IPHONE_55",
}

BASE = "https://api.appstoreconnect.apple.com"

# ─── JWT ──────────────────────────────────────────────────────────────────────
def _b64u(d):
    if isinstance(d, str): d = d.encode()
    return base64.urlsafe_b64encode(d).rstrip(b"=").decode()

_tok_cache = [None, 0]

def make_token():
    now = int(time.time())
    if _tok_cache[0] and now - _tok_cache[1] < 1500:
        return _tok_cache[0]
    hdr = _b64u(json.dumps({"alg":"ES256","kid":KEY_ID,"typ":"JWT"}, separators=(',',':')))
    pay = _b64u(json.dumps({"iss":ISSUER_ID,"iat":now,"exp":now+1200,"aud":"appstoreconnect-v1"}, separators=(',',':')))
    msg = f"{hdr}.{pay}".encode()
    sig = _privkey.sign(msg, ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(sig)
    tok = f"{hdr}.{pay}.{_b64u(r.to_bytes(32,'big')+s.to_bytes(32,'big'))}"
    _tok_cache[0] = tok; _tok_cache[1] = now
    return tok

def _hdrs(extra=None):
    h = {"Authorization": f"Bearer {make_token()}", "Content-Type": "application/json"}
    if extra: h.update(extra)
    return h

def api_get(path, params=""):
    url = BASE + path + (("?" + params) if params else "")
    try:
        req = urllib.request.Request(url, headers=_hdrs())
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read()), r.status
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:300]
        print(f"    ⚠ API HTTP {e.code}: {body[:150]}")
        return {"_err": e.code, "_body": body}, e.code
    except Exception as e:
        print(f"    ⚠ API hatası ({type(e).__name__}): {e}")
        return {"_err": str(e)}, 0

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data=data, headers=_hdrs(), method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return (json.loads(raw) if raw else {}), r.status
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:500]
        print(f"    POST {path} {e.code}: {body[:200]}")
        return {"_err": e.code, "_body": body}, e.code

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data=data, headers=_hdrs(), method="PATCH")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return (json.loads(raw) if raw else {}), r.status
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:300]
        return {"_err": e.code, "_body": body}, e.code

def api_delete(path):
    req = urllib.request.Request(BASE + path, headers=_hdrs(), method="DELETE")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code

def upload_file(upload_url, file_path):
    """S3'e direkt yükle."""
    data = file_path.read_bytes()
    req = urllib.request.Request(upload_url, data=data, method="PUT",
                                  headers={"Content-Type": "image/png",
                                           "Content-Length": str(len(data))})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code

def md5b64(file_path):
    import hashlib, base64
    return base64.b64encode(hashlib.md5(file_path.read_bytes()).digest()).decode()

# ─── ASC helpers ──────────────────────────────────────────────────────────────

def get_edit_version(app_id):
    """Düzenlenebilir versiyon bul; READY_FOR_SALE ise yeni versiyon oluştur."""
    EDITABLE = {"PREPARE_FOR_SUBMISSION","DEVELOPER_REJECTED","REJECTED","METADATA_REJECTED","INVALID_BINARY"}
    IN_REVIEW = {"WAITING_FOR_REVIEW","IN_REVIEW","PENDING_DEVELOPER_RELEASE",
                 "PENDING_APPLE_RELEASE","PROCESSING_FOR_APP_STORE"}

    d, code = api_get(f"/v1/apps/{app_id}/appStoreVersions",
                      "filter[platform]=IOS&limit=5")
    if "_err" in d:
        print(f"  ⚠ versions API {code}: {d.get('_body','')[:100]}")
    versions = d.get("data", [])
    print(f"  versions: {[v['attributes'].get('appStoreState','?')+'/'+v['attributes']['versionString'] for v in versions]}")

    for v in versions:
        state = v["attributes"].get("appStoreState", "")
        if state in EDITABLE:
            return v["id"], v["attributes"]["versionString"]

    # İncelemede: screenshot güncellemesi için yeni versiyon gerekli
    # Önce READY_FOR_SALE var mı bak
    ready_version = None
    for v in versions:
        state = v["attributes"].get("appStoreState", "")
        if state == "READY_FOR_SALE":
            ready_version = v
            break

    # READY_FOR_SALE ise yeni versiyon oluştur
    if ready_version:
        old_ver = ready_version["attributes"]["versionString"]
        parts = old_ver.split(".")
        try:
            parts[-1] = str(int(parts[-1]) + 1)
        except:
            parts.append("1")
        new_ver = ".".join(parts)
        print(f"  📦 READY_FOR_SALE: yeni versiyon {new_ver} oluşturuluyor...")
        body = {"data": {"type": "appStoreVersions",
                         "attributes": {"platform": "IOS", "versionString": new_ver},
                         "relationships": {"app": {"data": {"type":"apps","id":app_id}}}}}
        res, code = api_post("/v1/appStoreVersions", body)
        if code in (200, 201) and "data" in res:
            vid = res["data"]["id"]
            print(f"  ✅ Yeni versiyon {new_ver} oluşturuldu (ID: {vid})")
            return vid, new_ver
        print(f"  ⚠ Versiyon oluşturulamadı ({code}): {res.get('_body','')[:200]}")
        # Yine de devam et: ready_for_sale sürümün screenshot setini güncellemeyi dene
        return ready_version["id"], old_ver

    # IN_REVIEW: screenshot değiştirilemez, log at
    for v in versions:
        state = v["attributes"].get("appStoreState", "")
        if state in IN_REVIEW:
            print(f"  ⚠ Versiyon incelemede ({state}). Screenshot güncellenemiyor, atlanıyor.")
            return None, None

    if versions:
        v = versions[0]
        return v["id"], v["attributes"]["versionString"]
    return None, None

def get_localizations(version_id):
    """Versiyon localizasyonlarını getir. {locale: locId}"""
    d, _ = api_get(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations",
                    "fields[appStoreVersionLocalizations]=locale&limit=50")
    result = {}
    for loc in d.get("data", []):
        result[loc["attributes"]["locale"]] = loc["id"]
    return result

def create_localization(version_id, locale):
    """Yeni localizasyon oluştur."""
    body = {"data": {"type": "appStoreVersionLocalizations",
                     "attributes": {"locale": locale},
                     "relationships": {"appStoreVersion": {"data": {"type":"appStoreVersions","id":version_id}}}}}
    d, code = api_post("/v1/appStoreVersionLocalizations", body)
    if code in (200, 201) and "data" in d:
        return d["data"]["id"]
    print(f"    ⚠ locale {locale} oluşturulamadı ({code}): {d.get('_body','')[:100]}")
    return None

def get_screenshot_sets(loc_id):
    """{displayType: setId}"""
    d, _ = api_get(f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets",
                    "fields[appScreenshotSets]=screenshotDisplayType&limit=50")
    result = {}
    for s in d.get("data", []):
        result[s["attributes"]["screenshotDisplayType"]] = s["id"]
    return result

def delete_screenshots_in_set(set_id):
    """Bir set içindeki tüm screenshot'ları sil."""
    d, _ = api_get(f"/v1/appScreenshotSets/{set_id}/appScreenshots",
                    "fields[appScreenshots]=id&limit=50")
    for ss in d.get("data", []):
        api_delete(f"/v1/appScreenshots/{ss['id']}")

def create_screenshot_set(loc_id, display_type):
    body = {"data": {"type": "appScreenshotSets",
                     "attributes": {"screenshotDisplayType": display_type},
                     "relationships": {"appStoreVersionLocalization": {"data": {"type":"appStoreVersionLocalizations","id":loc_id}}}}}
    d, code = api_post("/v1/appScreenshotSets", body)
    if code in (200, 201) and "data" in d:
        return d["data"]["id"]
    print(f"    ⚠ set {display_type} oluşturulamadı ({code})")
    return None

def upload_screenshot(set_id, file_path, order):
    """Tek screenshot yükle → reserve → upload → confirm."""
    fname = file_path.name
    fsize = file_path.stat().st_size
    # 1. Reserve
    body = {"data": {"type": "appScreenshots",
                     "attributes": {"fileName": fname, "fileSize": fsize},
                     "relationships": {"appScreenshotSet": {"data": {"type":"appScreenshotSets","id":set_id}}}}}
    d, code = api_post("/v1/appScreenshots", body)
    if code not in (200, 201) or "data" not in d:
        print(f"    ✗ reserve {fname}: {code}")
        return False
    ss_id = d["data"]["id"]
    ops = d["data"]["attributes"].get("uploadOperations", [])
    if not ops:
        print(f"    ✗ uploadOperations boş {fname}")
        return False
    # 2. Upload (S3)
    op = ops[0]
    up_url = op["url"]
    put_hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
    put_hdrs["Content-Type"] = "image/png"
    data = file_path.read_bytes()
    req = urllib.request.Request(up_url, data=data, method="PUT", headers=put_hdrs)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            up_ok = r.status in (200, 204)
    except urllib.error.HTTPError as e:
        print(f"    ✗ S3 upload {fname}: {e.code}")
        return False
    if not up_ok:
        print(f"    ✗ S3 upload başarısız {fname}")
        return False
    # 3. Confirm (md5)
    chk = md5b64(file_path)
    patch = {"data": {"type": "appScreenshots", "id": ss_id,
                      "attributes": {"uploaded": True, "sourceFileChecksum": chk}}}
    _, pcode = api_patch(f"/v1/appScreenshots/{ss_id}", patch)
    ok = pcode in (200, 201)
    if not ok: print(f"    ✗ confirm {fname}: {pcode}")
    return ok


# ─── Ana yükleme mantığı ──────────────────────────────────────────────────────

def process_app(app_dir_name, app_id):
    app_dir = SS_DIR / app_dir_name
    if not app_dir.exists():
        print(f"  ⏭ {app_dir_name} dizini yok, atlanıyor")
        return

    print(f"\n📱 {app_dir_name} (ASC ID: {app_id})")
    version_id, version_str = get_edit_version(app_id)
    if not version_id:
        print(f"  ❌ Düzenlenebilir versiyon bulunamadı")
        return
    print(f"  Versiyon: {version_str} (ID: {version_id})")

    existing_locs = get_localizations(version_id)
    print(f"  Mevcut locale'ler: {list(existing_locs.keys())}")

    # Her locale dizini
    for loc_dir in sorted(app_dir.iterdir()):
        if not loc_dir.is_dir(): continue
        dir_locale = loc_dir.name
        asc_locale = DIR_TO_LOCALE.get(dir_locale, dir_locale)

        # Localization ID bul veya oluştur
        loc_id = existing_locs.get(asc_locale)
        if not loc_id:
            print(f"  🌍 {asc_locale} locale oluşturuluyor...")
            loc_id = create_localization(version_id, asc_locale)
            if loc_id:
                existing_locs[asc_locale] = loc_id
            else:
                continue

        print(f"  📍 {asc_locale} (loc: {loc_id})")
        existing_sets = get_screenshot_sets(loc_id)

        # Her boyut dizini
        for size_dir in sorted(loc_dir.iterdir()):
            if not size_dir.is_dir(): continue
            display_type = SIZE_TO_DISPLAY.get(size_dir.name)
            if not display_type:
                continue

            png_files = sorted(size_dir.glob("*.png"))
            if not png_files: continue

            # Mevcut seti temizle veya oluştur
            set_id = existing_sets.get(display_type)
            if set_id:
                print(f"    🗑 {display_type} eski screenshot'lar siliniyor...")
                delete_screenshots_in_set(set_id)
                # Set'i de sil ve yeniden oluştur
                api_delete(f"/v1/appScreenshotSets/{set_id}")
                time.sleep(0.5)

            print(f"    📁 {display_type} — {len(png_files)} dosya yüklenecek")
            new_set_id = create_screenshot_set(loc_id, display_type)
            if not new_set_id:
                continue

            ok_count = 0
            for i, png in enumerate(png_files):
                print(f"      ⬆ {png.name}", end="... ", flush=True)
                if upload_screenshot(new_set_id, png, i+1):
                    print("✅")
                    ok_count += 1
                    time.sleep(0.3)
                else:
                    print("❌")
                    time.sleep(0.5)

            print(f"    ✅ {ok_count}/{len(png_files)} yüklendi — {asc_locale}/{size_dir.name}/{display_type}")

    print(f"  ✅ {app_dir_name} tamamlandı")


def main():
    print("🚀 App Store Connect Screenshot Uploader başlıyor...")
    print(f"📂 Screenshot dizini: {SS_DIR}")

    target = os.environ.get("APP_TARGET", "all")
    for dir_name, app_id in APPS.items():
        if target != "all" and target != dir_name:
            continue
        process_app(dir_name, app_id)

    print("\n🎉 Tüm yüklemeler tamamlandı!")

if __name__ == "__main__":
    main()
