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
        if let o = try? JSONSerialization.jsonObject(with: d) as? [String:Any] { return (o["items"] as? [[String:Any]]) ?? [] }
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
    // İşletme
    func bizVeri(_ kind: String) async -> [[String:Any]] { await getArr("/dash/biz/\(kind)") }
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
}
