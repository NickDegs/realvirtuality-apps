import SwiftUI
import WidgetKit

// MARK: - Modeller
struct Durum: Decodable {
    var ok: Bool
    var kredi: Int
    var free_kalan: Int?
    var email: String?
    var davet_link: String?
    var davet_sayi: Int?
}

struct Klip: Identifiable {
    let id: String
    let url: String
    let baslik: String
    let emoji: String
}

struct UretimSonuc {
    var metin: String?
    var gorselData: Data?
    var klipler: [Klip]? = nil
    var videoURL: String? = nil
    var audioURL: String? = nil
    var gorselURL: String? = nil
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
    static weak var shared: API?
    init() { API.shared = self }

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
        if let v = aktifSid(), !v.isEmpty {
            kv.set(v, forKey: "rv_sid"); kv.synchronize()
            // Share Extension'ın kullanıcı oturumuyla çalışması için App Group'a da yaz
            UserDefaults(suiteName: "group.com.nickdegs.realvirtualityai")?.set(v, forKey: "rv_sid")
        }
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
        await AppAttest.shared.ensureToken()   // GÜVENLİK: istekten önce attest token garanti (race önle)
        var r = URLRequest(url: URL(string: API.base + yol)!)
        r.httpMethod = method
        r.timeoutInterval = timeout
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in AppAttest.headerSync() { r.setValue(v, forHTTPHeaderField: k) }   // GÜVENLİK: attest token
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
            widgetGuncelle()
        }
    }

    // Krediyi App Group'a yaz + widget'ı yenile (ana ekran widget'ı kredi gösterir)
    func widgetGuncelle() {
        UserDefaults(suiteName: "group.com.nickdegs.realvirtualityai")?.set(girisli ? kredi : freeKalan, forKey: "rv_kredi")
        WidgetCenter.shared.reloadAllTimelines()
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

    // MARK: - Push bildirim token kaydı
    func pushKaydet() async {
        guard let tok = UserDefaults.standard.string(forKey: "rv_push_token"), !tok.isEmpty else { return }
        _ = try? await istek("/api/push-kaydet", ["device_token": tok])
    }

    // MARK: - Günlük kredi + Davet
    func gunlukKrediAl() async -> (ok: Bool, miktar: Int, seri: Int, bonus: Bool, mesaj: String) {
        let j = (try? await istek("/api/gunluk-kredi", [:])) ?? [:]
        if let k = j["kredi"] as? Int { kredi = k; widgetGuncelle() }
        let ok = j["ok"] as? Bool == true
        return (ok, j["miktar"] as? Int ?? 0, j["seri"] as? Int ?? 0, j["bonus"] as? Bool ?? false,
                j["mesaj"] as? String ?? (ok ? "" : "Giriş gerekli"))
    }
    func davetBilgi() async -> (kod: String, link: String, davetSayisi: Int, kazanilan: Int)? {
        guard let j = try? await istek("/api/davet-kod", nil, method: "GET"), j["ok"] as? Bool == true else { return nil }
        return (j["kod"] as? String ?? "", j["link"] as? String ?? "",
                j["davet_sayisi"] as? Int ?? 0, j["kazanilan"] as? Int ?? 0)
    }
    func davetKullan(_ kod: String) async -> String? {
        let j = (try? await istek("/api/davet-kullan", ["kod": kod])) ?? [:]
        if j["ok"] as? Bool == true { if let k = j["kredi"] as? Int { kredi = k; widgetGuncelle() }; return nil }
        return j["mesaj"] as? String ?? j["err"] as? String ?? "Hata"
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
        let j = (try? await istek(yol, govde, timeout: 300)) ?? [:]
        if j["ok"] as? Bool == true {
            if let k = j["kredi"] as? Int { kredi = k }
            let p = (govde["prompt"] as? String) ?? (govde["metin"] as? String) ?? ""
            // fal.ai medya çıktıları (URL): video / müzik / try-on görseli
            if let v = j["video"] as? String, v.hasPrefix("http") { return (UretimSonuc(videoURL: v), nil) }
            if let a = j["audio"] as? String, a.hasPrefix("http") { return (UretimSonuc(audioURL: a), nil) }
            var data: Data? = nil; var gURL: String? = nil
            if let s = j["image"] as? String {
                if s.hasPrefix("http") { gURL = s }
                else if let c = s.range(of: ","), let d = Data(base64Encoded: String(s[c.upperBound...])) {
                    data = d
                    await ciktiKaydet(arac: aracAdi(yol), tip: "gorsel", baslik: p, prompt: p, dataB64: s)
                }
            }
            let m = j["metin"] as? String
            if let m = m, data == nil {
                await ciktiKaydet(arac: aracAdi(yol), tip: "metin", baslik: String(m.prefix(60)), prompt: p, metin: m)
            }
            return (UretimSonuc(metin: m, gorselData: data, gorselURL: gURL), nil)
        }
        if (j["err"] as? String) == "kota_doldu" { return (nil, "kota_doldu") }
        return (nil, (j["mesaj"] as? String) ?? (j["err"] as? String) ?? "Üretilemedi")
    }

    // Video oto-klip — multipart video upload + iş kuyruğu polling. (UretimSonuc.klipler döner)
    func klipUret(_ videoURL: URL, adet: Int, format: String, altyazi: String, muzik: String) async -> (UretimSonuc?, String?) {
        yukleniyor = true; defer { yukleniyor = false }
        guard let veri = try? Data(contentsOf: videoURL) else { return (nil, "Video okunamadı") }

        let boundary = "rvb-\(UUID().uuidString)"
        var r = URLRequest(url: URL(string: API.base + "/api/klip")!)
        r.httpMethod = "POST"; r.timeoutInterval = 120
        r.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        for (k, v) in AppAttest.headerSync() { r.setValue(v, forHTTPHeaderField: k) }   // GÜVENLİK: attest token
        var govde = Data()
        func alan(_ ad: String, _ deger: String) {
            govde.append("--\(boundary)\r\n".data(using: .utf8)!)
            govde.append("Content-Disposition: form-data; name=\"\(ad)\"\r\n\r\n".data(using: .utf8)!)
            govde.append("\(deger)\r\n".data(using: .utf8)!)
        }
        let lang = Locale.current.language.languageCode?.identifier ?? "tr"
        alan("lang", lang); alan("adet", String(adet)); alan("format", format); alan("altyazi", altyazi)
        if !muzik.isEmpty { alan("muzik", muzik) }
        govde.append("--\(boundary)\r\n".data(using: .utf8)!)
        govde.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
        govde.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        govde.append(veri)
        govde.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        r.httpBody = govde

        guard let (d, resp) = try? await session.upload(for: r, from: govde) else { return (nil, "Yüklenemedi") }
        guard let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return (nil, "Yüklenemedi") }
        if j["ok"] as? Bool != true {
            if (j["err"] as? String) == "kota_doldu" { return (nil, "kota_doldu") }
            _ = resp
            return (nil, (j["mesaj"] as? String) ?? (j["err"] as? String) ?? "Yüklenemedi")
        }
        guard let jid = j["job"] as? String else { return (nil, "İş başlatılamadı") }

        // İş kuyruğu polling (max ~5 dk) — klip işleme whisper+ffmpeg uzun sürebilir
        for _ in 0..<100 {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let p = (try? await istek("/api/klip-durum/\(jid)", nil, method: "GET", timeout: 30)) ?? [:]
            if let k = p["kredi"] as? Int { kredi = k }
            let durum = p["durum"] as? String ?? ""
            if durum == "bitti" {
                let ham = p["klipler"] as? [[String: Any]] ?? []
                let klipler = ham.map { k in
                    Klip(id: k["id"] as? String ?? UUID().uuidString,
                         url: k["url"] as? String ?? "",
                         baslik: k["baslik"] as? String ?? "Klip",
                         emoji: k["emoji"] as? String ?? "🎬")
                }
                if klipler.isEmpty { return (nil, (p["mesaj"] as? String) ?? "Klip çıkarılamadı") }
                return (UretimSonuc(metin: nil, gorselData: nil, klipler: klipler), nil)
            }
            if durum == "hata" { return (nil, (p["mesaj"] as? String) ?? "İşleme hatası") }
        }
        return (nil, "İşlem zaman aşımına uğradı, kütüphaneden kontrol et")
    }

    // Katalog ürün siparişi — native akış, SMS ile ödeme linki gönderilir
    func urunSiparis(_ urunId: String) async -> (siparisId: String?, mesaj: String?, hata: String?) {
        let j = (try? await istek("/api/urun-siparis", ["urun_id": urunId])) ?? [:]
        if j["ok"] as? Bool == true {
            return (j["siparis_id"] as? String, j["mesaj"] as? String ?? "Sipariş alındı.", nil)
        }
        return (nil, nil, j["err"] as? String ?? "Sipariş oluşturulamadı")
    }

    // Seslendirme — ses (mp3) verisi döndürür
    func sesUret(_ metin: String) async -> (Data?, String?) {
        yukleniyor = true; defer { yukleniyor = false }
        var r = URLRequest(url: URL(string: API.base + "/api/tts")!)
        r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in AppAttest.headerSync() { r.setValue(v, forHTTPHeaderField: k) }   // GÜVENLİK: attest token
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
