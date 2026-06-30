import Foundation
import DeviceCheck
import CryptoKit

// ── NickDegs App Attest istemcisi (RV AI / Business / Dashboard ortak) ──
// Apple donanım-imzalı uygulama bütünlüğü. Sideload/değiştirilmiş IPA/script/replay → sunucu reddeder.
// Akış: hazirla() ilk açılışta key üret+attest+register → token. oturumYenile() her oturumda assertion→token.
// API çağrılarına token "X-Attest-Token" header'ı ile eklenir. Backend attest_verify ile doğrular.
@MainActor
final class AppAttest: ObservableObject {
    static let shared = AppAttest()
    private let service = DCAppAttestService.shared
    private let base = "https://nickdegs.com/attest"      // nginx → 127.0.0.1:9300
    private let appId = Bundle.main.bundleIdentifier ?? ""
    private let KID = "ndg_attest_keyid"

    @Published private(set) var token: String? {
        didSet { UserDefaults.standard.set(token, forKey: "ndg_attest_token") }   // nonisolated okuma için
    }
    private var keyId: String? {
        get { UserDefaults.standard.string(forKey: KID) }
        set { UserDefaults.standard.set(newValue, forKey: KID) }
    }

    /// Herhangi bir context'ten (MainActor olmayan API layer) okunabilir attest header.
    nonisolated static func headerSync() -> [String: String] {
        if let t = UserDefaults.standard.string(forKey: "ndg_attest_token"), !t.isEmpty {
            return ["X-Attest-Token": t]
        }
        return [:]
    }

    /// Cihaz App Attest destekliyor mu (simülatör/eski cihaz: false → token üretilmez, backend grace).
    var destekli: Bool { service.isSupported }

    /// İlk kurulum + oturum token'ı. Açılışta çağır. Başarısızsa token nil kalır.
    @discardableResult
    func hazirla() async -> Bool {
        guard service.isSupported else { return false }            // simülatör/review-dışı: attest yok
        if keyId != nil { return await oturumYenile() }            // zaten kayıtlı → assertion ile token
        do {
            let ch = try await challenge()
            let key = try await service.generateKey()
            let hash = Data(SHA256.hash(data: Data(ch.utf8)))
            let att  = try await service.attestKey(key, clientDataHash: hash)
            if try await register(keyId: key, attestation: att, challenge: ch) {
                keyId = key
                return true
            }
        } catch { }
        return false
    }

    /// Her oturum/uzun süre sonra: assertion ile yeni kısa-ömürlü token.
    @discardableResult
    func oturumYenile() async -> Bool {
        guard service.isSupported, let kid = keyId else { return false }
        do {
            let ch = try await challenge()
            let hash = Data(SHA256.hash(data: Data(ch.utf8)))
            let assertion = try await service.generateAssertion(kid, clientDataHash: hash)
            return try await assert(keyId: kid, assertion: assertion, clientData: ch)
        } catch { return false }
    }

    /// API isteklerine eklenecek header (token yoksa boş — backend grace/deny politikasına göre).
    var header: [String: String] { token.map { ["X-Attest-Token": $0] } ?? [:] }

    /// İstekten ÖNCE çağrılır (race önleme): token yoksa (ilk açılış) attest yapar, varsa anında döner.
    /// ENFORCE modunda ilk isteğin token'sız gitmesini engeller.
    func ensureToken() async {
        if !AppAttest.headerSync().isEmpty { return }   // UserDefaults'ta token var → hızlı çık
        guard service.isSupported else { return }       // simülatör/desteklemeyen → boş geç
        _ = await hazirla()
    }

    // ── Sunucu çağrıları ──
    private func challenge() async throws -> String {
        let r = try await post("/challenge", ["app": appId])
        guard let c = r["challenge"] as? String else { throw Hata.sunucu }
        return c
    }
    private func register(keyId: String, attestation: Data, challenge: String) async throws -> Bool {
        let r = try await post("/register", [
            "app": appId, "keyId": keyId,
            "attestation": attestation.base64EncodedString(),
            "challenge": challenge])
        if let t = r["token"] as? String { token = t; return true }
        return false
    }
    private func assert(keyId: String, assertion: Data, clientData: String) async throws -> Bool {
        let r = try await post("/assert", [
            "app": appId, "keyId": keyId,
            "assertion": assertion.base64EncodedString(),
            "clientData": clientData])
        if let t = r["token"] as? String { token = t; return true }
        return false
    }

    private func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 20
        let (d, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? [:]
    }

    enum Hata: Error { case sunucu }
}
