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

// MARK: - API İstemcisi (realvirtuality.app — çerez tabanlı oturum)
@MainActor
final class API: ObservableObject {
    static let base = "https://realvirtuality.app"

    @Published var kredi: Int = 0
    @Published var freeKalan: Int = 0
    @Published var email: String? = nil
    @Published var girisli: Bool = false
    @Published var yukleniyor: Bool = false

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.httpCookieStorage = HTTPCookieStorage.shared
        c.httpShouldSetCookies = true
        c.httpCookieAcceptPolicy = .always
        return URLSession(configuration: c)
    }()

    private func istek(_ yol: String, _ govde: [String: Any]? = nil, method: String = "POST") async throws -> [String: Any] {
        var r = URLRequest(url: URL(string: API.base + yol)!)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let g = govde { r.httpBody = try JSONSerialization.data(withJSONObject: g) }
        let (data, _) = try await session.data(for: r)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func durumYukle() async {
        if let j = try? await istek("/api/durum", nil, method: "GET") {
            kredi = j["kredi"] as? Int ?? 0
            freeKalan = j["free_kalan"] as? Int ?? 0
            email = j["email"] as? String
            girisli = email != nil
        }
    }

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
        girisli = false; email = nil; await durumYukle()
    }

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
            return (UretimSonuc(metin: m, gorselData: nil), nil)
        }
        return (nil, (j["mesaj"] as? String) ?? (j["err"] as? String) ?? "Üretilemedi")
    }
}
