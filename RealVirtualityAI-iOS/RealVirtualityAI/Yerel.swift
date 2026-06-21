import SwiftUI

// MARK: - Çok dilli yönetim (otomatik cihaz dili + manuel seçim)
@MainActor
final class Yerel: ObservableObject {
    static let diller = ["tr","en","de","fr","es","ar","ru"]
    static let dilAd: [String:String] = [
        "tr":"Türkçe","en":"English","de":"Deutsch","fr":"Français","es":"Español","ar":"العربية","ru":"Русский"]

    // "" = cihaz dili (otomatik); aksi halde manuel seçim
    @AppStorage("dil_secim") var secim = "" { didSet { objectWillChange.send() } }

    var aktif: String {
        if !secim.isEmpty, Yerel.diller.contains(secim) { return secim }
        let sys = String((Locale.preferredLanguages.first ?? "en").prefix(2)).lowercased()
        return Yerel.diller.contains(sys) ? sys : "en"
    }
    var rtl: Bool { aktif == "ar" }
    var yon: LayoutDirection { rtl ? .rightToLeft : .leftToRight }

    // ── UI metinleri ──
    private static let ui: [String:[String:String]] = yukleUI()
    func t(_ key: String) -> String {
        let tbl = Yerel.ui[key] ?? [:]
        return tbl[aktif] ?? tbl["en"] ?? tbl["tr"] ?? key
    }

    // ── Araç içeriği ──
    private static let araclarI18n: [String:[String:Any]] = yukleAraclar()
    private func aracTbl(_ id: String) -> [String:Any] {
        let t = araclarI18nFor(id, aktif)
        return t
    }
    private func araclarI18nFor(_ id: String, _ lang: String) -> [String:Any] {
        let per = Yerel.araclarI18n[id] as? [String:Any] ?? [:]
        return (per[lang] as? [String:Any]) ?? (per["en"] as? [String:Any]) ?? (per["tr"] as? [String:Any]) ?? [:]
    }
    func aracMetin(_ id: String, _ alan: String) -> String { (aracTbl(id)[alan] as? String) ?? "" }
    func aracDizi(_ id: String, _ alan: String) -> [String] { (aracTbl(id)[alan] as? [String]) ?? [] }

    // ── JSON yükleyiciler ──
    private static func yukleUI() -> [String:[String:String]] {
        guard let u = Bundle.main.url(forResource: "ui_i18n", withExtension: "json"),
              let d = try? Data(contentsOf: u),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String:[String:String]] else { return [:] }
        return j
    }
    private static func yukleAraclar() -> [String:[String:Any]] {
        guard let u = Bundle.main.url(forResource: "araclar_i18n", withExtension: "json"),
              let d = try? Data(contentsOf: u),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String:[String:Any]] else { return [:] }
        return j
    }
}
