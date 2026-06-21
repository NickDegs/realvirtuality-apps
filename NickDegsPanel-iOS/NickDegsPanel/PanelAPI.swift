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
    // İşletme
    func bizVeri(_ kind: String) async -> [[String:Any]] { await getArr("/dash/biz/\(kind)") }
    // Güvenlik
    func guvenlik(_ tip: String) async -> [String:Any]? { await get("/api/panel/guvenlik", ["tip":tip]) }
    // İşletme ekle (süper)
    func slugListesi() async -> [String] { ((await get("/api/panel/slugs"))?["slugs"] as? [String]) ?? [] }
    func isletmeEkle(ad: String, kod: String, tel: String, sifre: String, slug: String) async -> [String:Any]? {
        await post("/api/panel/isletme-ekle", ["ad":ad,"kod":kod,"tel":tel,"sifre":sifre,"slug":slug])
    }
}
