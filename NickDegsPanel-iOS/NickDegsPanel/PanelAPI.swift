import SwiftUI

// MARK: - Native veri istemcisi (WebView yok — JSON API'lerden çeker)
@MainActor
final class PanelAPI {
    let host: String
    let token: String
    init(host: String, token: String) {
        self.host = host.hasPrefix("http") ? host : "https://" + host
        self.token = token
    }
    private func url(_ yol: String, _ q: [String:String] = [:]) -> URL {
        var c = URLComponents(string: host + yol)!
        var items = [URLQueryItem(name: "t", value: token), URLQueryItem(name: "_t", value: token)]
        for (k,v) in q { items.append(URLQueryItem(name: k, value: v)) }
        c.queryItems = items
        return c.url!
    }
    func get(_ yol: String, _ q: [String:String] = [:]) async -> [String:Any]? {
        guard let (d,_) = try? await URLSession.shared.data(from: url(yol,q)) else { return nil }
        return try? JSONSerialization.jsonObject(with: d) as? [String:Any]
    }
    func getArr(_ yol: String, _ q: [String:String] = [:]) async -> [[String:Any]] {
        guard let (d,_) = try? await URLSession.shared.data(from: url(yol,q)) else { return [] }
        if let a = try? JSONSerialization.jsonObject(with: d) as? [[String:Any]] { return a }
        if let o = try? JSONSerialization.jsonObject(with: d) as? [String:Any] {
            // farklı backend anahtarlarını dene (items/recent/data/list/kayitlar/...)
            for k in ["items","recent","data","list","kayitlar","results","rows","kanallar","kullanicilar","uyeler","odemeler","containers","ips"] {
                if let arr = o[k] as? [[String:Any]] { return arr }
            }
        }
        return []
    }
    private func post(_ yol: String, _ body: [String:Any]) async -> [String:Any]? {
        var r = URLRequest(url: url(yol)); r.httpMethod = "POST"; r.timeoutInterval = 40
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var b = body; b["t"] = token
        r.httpBody = try? JSONSerialization.data(withJSONObject: b)
        guard let (d,_) = try? await URLSession.shared.data(for: r) else { return nil }
        return try? JSONSerialization.jsonObject(with: d) as? [String:Any]
    }

    // Sunucu
    func durum() async -> [String:Any]? { await get("/api/panel/durum") }
    func servisRestart(_ svc: String) async -> Bool { (await post("/api/panel/servis-restart", ["svc":svc]))?["ok"] as? Bool ?? false }
#if IPTV_MODULE
    // IPTV
    func iptvDurum() async -> [String:Any]? { await get("/dash/iptv/durum") }
    func iptvKanallar() async -> [[String:Any]] { await getArr("/dash/iptv/kanallar") }
    func iptvKanalAksiyon(_ id: String, _ aksiyon: String) async -> Bool { (await post("/dash/iptv/kanal-aksiyon", ["id":id,"aksiyon":aksiyon]))?["ok"] as? Bool ?? false }
    func iptvHatAksiyon(_ id: String, _ aksiyon: String) async -> Bool { (await post("/dash/iptv/hat-aksiyon", ["id":id,"aksiyon":aksiyon]))?["ok"] as? Bool ?? false }
    func iptvKullanicilar() async -> [[String:Any]] { await getArr("/dash/iptv/kullanicilar") }
    func iptvDavetler() async -> [[String:Any]] { ((await get("/dash/iptv/davetler"))?["users"] as? [[String:Any]]) ?? [] }
    func iptvDavet(_ body: [String:Any]) async -> [String:Any]? { await post("/dash/iptv/davet", body) }
    func iptvDavetIptal(_ kullanici: String) async -> Bool { (await post("/dash/iptv/davet-iptal", ["kullanici":kullanici]))?["ok"] as? Bool ?? false }
    func iptvDavetUzat(_ kullanici: String, _ gun: Int) async -> Bool { (await post("/dash/iptv/davet-uzat", ["kullanici":kullanici,"gun":gun]))?["ok"] as? Bool ?? false }
    func iptvKaynakGuncelle(_ adresler: [String]) async -> Bool { (await post("/dash/iptv/kaynak-guncelle", ["adresler":adresler]))?["ok"] as? Bool ?? false }
#endif  // IPTV_MODULE
    // İşletme
    func bizVeri(_ kind: String) async -> [[String:Any]] { await getArr("/dash/biz/\(kind)") }
    // İşletme yönetim aksiyonu (sektör proxy GET+POST) — sipariş ilerlet, menü toggle, randevu vb.
    @discardableResult
    func bizAksiyon(_ yol: String, _ body: [String:Any] = [:]) async -> Bool {
        (await post("/dash/biz/\(yol)", body))?["ok"] as? Bool ?? false
    }
    // Güvenlik
    func guvenlik(_ tip: String) async -> [String:Any]? { await get("/api/panel/guvenlik", ["tip":tip]) }
    // İşletme ekle (süper)
    func slugListesi() async -> [String] { ((await get("/api/panel/slugs"))?["slugs"] as? [String]) ?? [] }
    func isletmeEkle(ad: String, kod: String, tel: String, sifre: String, slug: String) async -> [String:Any]? {
        await post("/api/panel/isletme-ekle", ["ad":ad,"kod":kod,"tel":tel,"sifre":sifre,"slug":slug])
    }
    // Personel (işletme → çalışan)
    func personelListe() async -> [[String:Any]] { ((await get("/api/panel/personel-liste"))?["personel"] as? [[String:Any]]) ?? [] }
    func personelEkle(ad: String, kod: String, tel: String, sifre: String) async -> [String:Any]? {
        await post("/api/panel/personel-ekle", ["ad":ad,"kod":kod,"tel":tel,"sifre":sifre])
    }
    func personelSil(_ kod: String) async { _ = await post("/api/panel/personel-sil", ["kod":kod]) }

    // ── Ülke erişimi ──
    func ulkeListe() async -> [[String:Any]] { ((await get("/api/panel/ulke-liste"))?["ulkeler"] as? [[String:Any]]) ?? [] }
    func ulkeToggle(_ cc: String, _ ac: Bool) async -> Bool { (await post("/api/panel/ulke-toggle", ["cc":cc,"ac":ac]))?["ok"] as? Bool ?? false }
    // ── Operatör / ASN ──
    func asnListe() async -> [[String:Any]] { ((await get("/api/panel/asn-liste"))?["operatorler"] as? [[String:Any]]) ?? [] }
    func asnToggle(_ asn: String, _ act: String) async -> Bool { (await post("/api/panel/asn-toggle", ["asn":asn,"act":act]))?["ok"] as? Bool ?? false }
    // ── IP yönetimi ──
    func ipAksiyon(_ ip: String, _ action: String) async -> [String:Any]? { await post("/api/panel/ip-aksiyon", ["ip":ip,"action":action]) }
    // ── Admin Hub ──
    func hubApps() async -> [[String:Any]] { ((await get("/api/panel/hub-apps"))?["apps"] as? [[String:Any]]) ?? [] }
    func hubAction(_ body: [String:Any]) async -> [String:Any]? { await post("/api/panel/hub-action", body) }
    // ── Hediye kod ──
    func hediyePaketler() async -> [[String:Any]] { ((await get("/dash/hediye/hediye-paketler"))?["paketler"] as? [[String:Any]]) ?? [] }
    func hediyeKodUret(_ paket: String, _ adet: Int, _ kime: String) async -> [String:Any]? { await post("/dash/hediye/kod-uret", ["paket":paket,"adet":adet,"kime":kime]) }
    // ── Demo üret ──
    func demoUret(_ body: [String:Any]) async -> [String:Any]? { await post("/api/panel/demo-uret", body) }
    func demoListe() async -> [[String:Any]] { ((await get("/api/panel/demo-liste"))?["kayitlar"] as? [[String:Any]]) ?? [] }

    // ── Medya: Emby / Plex / indirme / istek / sistem (tv.nickdegs.com) ──
#if IPTV_MODULE
    func embyOzet() async -> [String:Any] { (await get("/dash/iptv/emby-ozet")) ?? [:] }
    func embyIcerik(_ tip: String, _ ara: String, _ offset: Int) async -> [[String:Any]] {
        ((await get("/dash/iptv/emby-icerik", ["tip":tip,"ara":ara,"offset":"\(offset)","limit":"60"]))?["items"] as? [[String:Any]]) ?? []
    }
    func plexOzet() async -> [String:Any] { (await get("/dash/iptv/plex-ozet")) ?? [:] }
    func plexIcerik(_ kutuphane: String, _ ara: String, _ offset: Int) async -> [[String:Any]] {
        ((await get("/dash/iptv/plex-icerik", ["kutuphane":kutuphane,"ara":ara,"offset":"\(offset)","limit":"60"]))?["items"] as? [[String:Any]]) ?? []
    }
    func indirmeler() async -> [[String:Any]] { ((await get("/dash/iptv/indirmeler"))?["indirmeler"] as? [[String:Any]]) ?? [] }
    func istekler() async -> [[String:Any]] { ((await get("/dash/iptv/istekler"))?["istekler"] as? [[String:Any]]) ?? [] }
    func sistemOzet() async -> [String:Any] { (await get("/dash/iptv/sistem-ozet")) ?? [:] }
#endif  // IPTV_MODULE
    // ── Abonelik / erişim (admin) ──
    func grant(email: String, days: Int, plan: String) async -> [String:Any]? {
        await post("/dash/aapi/grant", ["email":email,"days":days,"plan":plan])
    }
    func uyeUzat(id: String, days: Int) async -> [String:Any]? {
        await post("/dash/aapi/extend", ["id":id,"days":days])
    }
    func uyeErisimKaldir(user: String) async -> [String:Any]? {
        await post("/dash/aapi/ent-action", ["action":"revoke_all","user":user])
    }
    // ── Admin Hub zamanlı duyuru ──
    func hubZamanla(_ body: [String:Any]) async -> [String:Any]? { await post("/api/panel/hub-schedule", body) }
    func hubZamanliListe() async -> [[String:Any]] { ((await get("/api/panel/hub-schedule"))?["kayitlar"] as? [[String:Any]]) ?? [] }
    // ── Kontrol Merkezi ──
    func gorevler() async -> [[String:Any]] { ((await get("/api/panel/gorevler"))?["gorevler"] as? [[String:Any]]) ?? [] }
    func gorevEkle(_ body: [String:Any]) async -> [String:Any]? { await post("/api/panel/gorev-ekle", body) }
    func gorevGuncelle(_ body: [String:Any]) async -> [String:Any]? { await post("/api/panel/gorev-guncelle", body) }
    func gorevSil(_ id: Int) async -> Bool { (await post("/api/panel/gorev-sil", ["id":id]))?["ok"] as? Bool ?? false }
    func claudeOturumlar() async -> [[String:Any]] { ((await get("/api/panel/claude-oturumlar"))?["oturumlar"] as? [[String:Any]]) ?? [] }
    func claudeCmd(_ oturum: String, _ komut: String) async -> Bool { (await post("/api/panel/claude-cmd", ["oturum":oturum,"komut":komut]))?["ok"] as? Bool ?? false }
    func claudeEkran(_ oturum: String) async -> String { (await get("/api/panel/claude-ekran", ["o":oturum]))?["icerik"] as? String ?? "" }
    func servislerDetay() async -> [[String:Any]] { ((await get("/api/panel/servisler-detay"))?["servisler"] as? [[String:Any]]) ?? [] }
    func servisAksiyon(_ servis: String, _ aksiyon: String) async -> Bool { (await post("/api/panel/servis-aksiyon", ["servis":servis,"aksiyon":aksiyon]))?["ok"] as? Bool ?? false }
    func servisLog(_ servis: String) async -> String { (await get("/api/panel/servis-log", ["s":servis]))?["log"] as? String ?? "" }
    func gitDurum() async -> [String:Any] { (await get("/api/panel/git-durum")) ?? [:] }
    // ── Meta Reklam Analiz ──
    func metaAnaliz() async -> [String:Any] { (await get("/api/panel/meta-analiz")) ?? [:] }
    // ── Satış & Gelir ──
    func satisOzet() async -> [String:Any] { (await get("/api/panel/satis-ozet")) ?? [:] }
    // ── Chat Logları (Matrix/Hush odaları) ──
    func matrixOdalar() async -> [[String:Any]] { ((await get("/api/panel/matrix-odalar"))?["odalar"] as? [[String:Any]]) ?? [] }
    // ── Traccar canlı konumlar ──
    func traccarKonumlar() async -> [[String:Any]] { ((await get("/api/panel/traccar-konumlar"))?["cihazlar"] as? [[String:Any]]) ?? [] }
    // ── Tam Koordinasyon ──
    func tamKoordinasyon() async -> [String:Any] { (await get("/api/panel/tam-koordinasyon")) ?? [:] }
    // ── Claude ekran görüntüsü (tek oturum) ──
    func oturumEkrani(_ o: String) async -> String { await claudeEkran(o) }
    // ── Satın Aldıklarım (işletme sahibi — panel/güvenlik/hush detayları) ──
    func satinAldiklarim() async -> [String:Any] { (await get("/api/panel/satinaldiklarim")) ?? ["ok":false,"mesaj":"Bağlantı hatası"] }
    // ── Hızlı Ödeme (anlık link & abonelik) ──
    func hizliOlustur(amount: Double, desc: String, customer: String, months: Int) async -> [String:Any]? {
        await post("/api/admin/paylink", ["amount":amount,"desc":desc,"customer":customer,"months":months])
    }
    func hizliSubs() async -> [[String:Any]] { await getArr("/api/admin/subs") }
    func hizliSubAksiyon(_ id: String, _ action: String) async -> Bool {
        (await post("/api/admin/sub-action", ["id":id,"action":action]))?["ok"] as? Bool ?? false
    }
    func hizliQRURL(_ link: String) -> URL? {
        var c = URLComponents(string: host + "/api/admin/qr")!
        c.queryItems = [URLQueryItem(name:"url",value:link), URLQueryItem(name:"token",value:token)]
        return c.url
    }
    // ── İşletme bilgisi (slug, site_url, sektör) ──
    func bizInfo() async -> [String:Any]? { await get("/api/panel/biz-info") }
    // ── Seslendir (Piper TTS) ──
    func seslendirTTS(metin: String, hiz: Double = 1.0) async -> [String:Any]? {
        await post("/dash/seslendir/tts", ["metin": metin, "hiz": hiz])
    }
    // ── AI Görsel (FLUX) ──
    func gorselUret(prompt: String, kalite: String = "normal") async -> [String:Any]? {
        await post("/dash/gorsel/uret", ["prompt": prompt, "kalite": kalite])
    }
    func gorselOzet() async -> [String:Any] { (await get("/dash/gorsel/ozet")) ?? [:] }
    // ── Hukuk Bürosu ──
    func hukukInstances() async -> [[String:Any]] { await getArr("/dash/hukuk/instances") }
    func hukukDavalar(_ did: String) async -> [[String:Any]] { await getArr("/dash/hukuk/davalar", ["did": did]) }
    func hukukSureler(_ did: String) async -> [[String:Any]] { await getArr("/dash/hukuk/sureler", ["did": did]) }
    // İşletme (business) — kendi tenant'ının hukuk verisi
    func bizHukukDavalar() async -> [[String:Any]] { await getArr("/dash/biz/hukuk-davalar") }
    func bizHukukSureler() async -> [[String:Any]] { await getArr("/dash/biz/hukuk-sureler") }
    // ── Müşteri işletmeleri (master admin) ──
    func isletmeler() async -> [String:Any]? { await get("/dash/isletmeler") }
    func isletmelerToken(biz: String) async -> String? {
        (await get("/dash/isletmeler/as", ["biz": biz]))?["token"] as? String
    }
    func isletmelerAksiyon(biz: String, aksiyon: String) async -> Bool {
        (await post("/dash/isletmeler/aksiyon", ["biz": biz, "aksiyon": aksiyon]))?["ok"] as? Bool ?? false
    }
    // ── Admin Panel (14-sekme native) ──
    func adminPost(_ yol: String, _ body: [String:Any]) async -> [String:Any]? {
        await post("/dash/aapi/\(yol)", body)
    }
    func adminIpAksiyon(_ ip: String, _ act: String) async -> [String:Any]? {
        await post("/dash/aapi/ip-action", ["ip": ip, "action": act])
    }
    func adminContainerAksiyon(_ name: String, _ action: String, _ server: String) async -> [String:Any]? {
        await post("/dash/aapi/container-action", ["name": name, "action": action, "server": server])
    }
}
