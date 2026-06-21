import SwiftUI

// MARK: - Modeller
struct Durum: Decodable {
    var ok: Bool
    var kredi: Int
    var free_kalan: Int?
    var email: String?
    var davet_link: String?
    var davet_sayi: Int?
}

struct UretimSonuc {
    var metin: String?
    var gorselData: Data?
}

struct KutuphaneItem: Identifiable {
    let id: String
    let arac: String
    let tip: String
    let baslik: String?
    let prompt: String?
    let metin: String?
    let gorsel: Bool
    let ts: Double
}

// MARK: - API İstemcisi (realvirtuality.app — çerez tabanlı oturum)
@MainActor
final class API: ObservableObject {
    static let base = "https://realvirtuality.app"

    @Published var kredi: Int = 0
    @Published var freeKalan: Int = 0
    @Published var email: String? = nil
    @Published var tel: String? = nil
    @Published var girisli: Bool = false
    @Published var yukleniyor: Bool = false

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.httpCookieStorage = HTTPCookieStorage.shared
        c.httpShouldSetCookies = true
        c.httpCookieAcceptPolicy = .always
        return URLSession(configuration: c)
    }()

    // MARK: - iCloud oturum senkronu (sid çerezi cihazlar arası taşınır — veri kaybı olmaz)
    private let kv = NSUbiquitousKeyValueStore.default
    private var siteURL: URL { URL(string: API.base)! }
    private func aktifSid() -> String? {
        HTTPCookieStorage.shared.cookies(for: siteURL)?.first { $0.name == "sid" }?.value
    }
    func iCloudTokenKaydet() {
        if let v = aktifSid(), !v.isEmpty { kv.set(v, forKey: "rv_sid"); kv.synchronize() }
    }
    func iCloudTokenYukle() {
        kv.synchronize()
        guard let v = kv.string(forKey: "rv_sid"), !v.isEmpty, aktifSid() != v else { return }
        if let c = HTTPCookie(properties: [
            .domain: "realvirtuality.app", .path: "/", .name: "sid", .value: v,
            .secure: "TRUE", .expires: Date().addingTimeInterval(31536000)
        ]) { HTTPCookieStorage.shared.setCookie(c) }
    }

    private func istek(_ yol: String, _ govde: [String: Any]? = nil, method: String = "POST", timeout: TimeInterval = 60) async throws -> [String: Any] {
        var r = URLRequest(url: URL(string: API.base + yol)!)
        r.httpMethod = method
        r.timeoutInterval = timeout
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let g = govde { r.httpBody = try JSONSerialization.data(withJSONObject: g) }
        let (data, _) = try await session.data(for: r)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func durumYukle() async {
        iCloudTokenYukle()   // önce iCloud'daki oturumu geri yükle
        if let j = try? await istek("/api/durum", nil, method: "GET") {
            kredi = j["kredi"] as? Int ?? 0
            freeKalan = j["free_kalan"] as? Int ?? 0
            email = j["email"] as? String
            tel = j["tel"] as? String
            girisli = (email != nil) || (tel != nil)
            if girisli { iCloudTokenKaydet() }
        }
    }

    // MARK: - SMS giriş
    func smsGonder(_ telno: String) async -> String? {
        let j = (try? await istek("/api/sms-gonder", ["tel": telno])) ?? [:]
        return (j["ok"] as? Bool == true) ? nil : (j["err"] as? String ?? "Hata")
    }
    func smsDogrula(_ telno: String, _ kod: String) async -> String? {
        let j = (try? await istek("/api/sms-dogrula", ["tel": telno, "kod": kod])) ?? [:]
        if j["ok"] as? Bool == true { iCloudTokenKaydet(); await durumYukle(); return nil }
        return j["err"] as? String ?? "Kod doğrulanamadı"
    }

    // MARK: - Çıktı kütüphanesi
    func ciktiKaydet(arac: String, tip: String, baslik: String, prompt: String, dataB64: String? = nil, metin: String? = nil) async {
        var g: [String: Any] = ["arac": arac, "tip": tip, "baslik": baslik, "prompt": prompt]
        if let d = dataB64 { g["data"] = d }
        if let m = metin { g["metin"] = m }
        _ = try? await istek("/api/cikti-kaydet", g)
    }
    func kutuphaneGetir() async -> [KutuphaneItem] {
        guard let j = try? await istek("/api/kutuphane", nil, method: "GET"),
              let arr = j["items"] as? [[String: Any]] else { return [] }
        return arr.compactMap { d in
            guard let id = d["id"] as? String else { return nil }
            return KutuphaneItem(id: id, arac: d["arac"] as? String ?? "", tip: d["tip"] as? String ?? "",
                                 baslik: d["baslik"] as? String, prompt: d["prompt"] as? String,
                                 metin: d["metin"] as? String, gorsel: d["gorsel"] as? Bool ?? false,
                                 ts: d["ts"] as? Double ?? 0)
        }
    }
    func ciktiSil(_ id: String) async {
        _ = try? await istek("/api/cikti/\(id)", nil, method: "DELETE")
    }
    func ciktiURL(_ id: String) -> URL { URL(string: API.base + "/api/cikti/\(id)")! }

    func kodGonder(_ eposta: String) async -> String? {
        let j = (try? await istek("/api/kod-gonder", ["email": eposta])) ?? [:]
        return (j["ok"] as? Bool == true) ? nil : (j["err"] as? String ?? "Hata")
    }

    func kodDogrula(_ eposta: String, _ kod: String, ref: String = "") async -> String? {
        let j = (try? await istek("/api/kod-dogrula", ["email": eposta, "kod": kod, "ref": ref])) ?? [:]
        if j["ok"] as? Bool == true { await durumYukle(); return nil }
        return j["err"] as? String ?? "Hata"
    }

    func cikis() async {
        _ = try? await istek("/api/cikis")
        kv.removeObject(forKey: "rv_sid"); kv.synchronize()
        girisli = false; email = nil; tel = nil; await durumYukle()
    }

    private func aracAdi(_ yol: String) -> String { yol.split(separator: "/").last.map(String.init) ?? "arac" }

    // IAP makbuzunu sunucuda doğrula → kredi yüklenir
    func iapDogrula(jws: String) async -> String? {
        let j = (try? await istek("/api/iap-dogrula", ["jws": jws])) ?? [:]
        if j["ok"] as? Bool == true { kredi = j["kredi"] as? Int ?? kredi; await durumYukle(); return nil }
        return j["err"] as? String ?? "doğrulanamadı"
    }

    // Sign in with Apple
    func appleGiris(idToken: String, email: String?) async -> String? {
        let j = (try? await istek("/api/apple-giris", ["identity_token": idToken, "email": email ?? ""])) ?? [:]
        if j["ok"] as? Bool == true { await durumYukle(); return nil }
        return j["err"] as? String ?? "Apple ile giriş başarısız"
    }

    // Görsel üretimi
    func gorselUret(_ prompt: String) async -> (UretimSonuc?, String?) {
        yukleniyor = true; defer { yukleniyor = false }
        let j = (try? await istek("/api/gorsel", ["prompt": prompt])) ?? [:]
        if j["ok"] as? Bool == true, let s = j["image"] as? String,
           let comma = s.range(of: ","), let d = Data(base64Encoded: String(s[comma.upperBound...])) {
            kredi = j["kredi"] as? Int ?? kredi
            await ciktiKaydet(arac: "gorsel", tip: "gorsel", baslik: prompt, prompt: prompt, dataB64: s)
            return (UretimSonuc(metin: nil, gorselData: d), nil)
        }
        return (nil, (j["mesaj"] as? String) ?? (j["err"] as? String) ?? "Üretilemedi")
    }

    // Metin tabanlı araçlar (yazi, ceviri, sohbet, seo, kod)
    func metinUret(_ yol: String, _ govde: [String: Any]) async -> (UretimSonuc?, String?) {
        yukleniyor = true; defer { yukleniyor = false }
        let j = (try? await istek(yol, govde)) ?? [:]
        if j["ok"] as? Bool == true, let m = j["metin"] as? String {
            kredi = j["kredi"] as? Int ?? kredi
            let p = (govde["prompt"] as? String) ?? (govde["metin"] as? String) ?? (govde["text"] as? String) ?? ""
            await ciktiKaydet(arac: aracAdi(yol), tip: "metin", baslik: String(m.prefix(60)), prompt: p, metin: m)
            return (UretimSonuc(metin: m, gorselData: nil), nil)
        }
        return (nil, (j["mesaj"] as? String) ?? (j["err"] as? String) ?? "Üretilemedi")
    }

    // Genel çağrı — görsel ve/veya metin döndüren tüm araçlar için
    func calistir(_ yol: String, _ govde: [String: Any]) async -> (UretimSonuc?, String?) {
        yukleniyor = true; defer { yukleniyor = false }
        let j = (try? await istek(yol, govde, timeout: 260)) ?? [:]
        if j["ok"] as? Bool == true {
            if let k = j["kredi"] as? Int { kredi = k }
            var data: Data? = nil
            let p = (govde["prompt"] as? String) ?? (govde["metin"] as? String) ?? ""
            if let s = j["image"] as? String, let c = s.range(of: ","),
               let d = Data(base64Encoded: String(s[c.upperBound...])) {
                data = d
                await ciktiKaydet(arac: aracAdi(yol), tip: "gorsel", baslik: p, prompt: p, dataB64: s)
            }
            let m = j["metin"] as? String
            if let m = m, data == nil {
                await ciktiKaydet(arac: aracAdi(yol), tip: "metin", baslik: String(m.prefix(60)), prompt: p, metin: m)
            }
            return (UretimSonuc(metin: m, gorselData: data), nil)
        }
        if (j["err"] as? String) == "kota_doldu" { return (nil, "kota_doldu") }
        return (nil, (j["mesaj"] as? String) ?? (j["err"] as? String) ?? "Üretilemedi")
    }

    // Seslendirme — ses (mp3) verisi döndürür
    func sesUret(_ metin: String) async -> (Data?, String?) {
        yukleniyor = true; defer { yukleniyor = false }
        var r = URLRequest(url: URL(string: API.base + "/api/tts")!)
        r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["text": metin])
        guard let (data, resp) = try? await session.data(for: r) else { return (nil, "Üretilemedi") }
        if let h = resp as? HTTPURLResponse, h.statusCode == 200,
           (h.value(forHTTPHeaderField: "Content-Type") ?? "").contains("audio") {
            await durumYukle()
            return (data, nil)
        }
        if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (nil, (j["err"] as? String) == "kota_doldu" ? "kota_doldu" : ((j["mesaj"] as? String) ?? "Üretilemedi"))
        }
        return (nil, "Üretilemedi")
    }
}
