import SwiftUI

// MARK: - Dil yönetimi (otomatik cihaz dili + manuel seçim)
@MainActor
final class Yerel: ObservableObject {
    static let diller = ["tr","en"]
    static let dilAd: [String:String] = ["tr":"Türkçe","en":"English"]
    @AppStorage("dil_secim") var secim = "" { didSet { objectWillChange.send() } }
    var aktif: String {
        if !secim.isEmpty, Yerel.diller.contains(secim) { return secim }
        let sys = String((Locale.preferredLanguages.first ?? "en").prefix(2)).lowercased()
        return Yerel.diller.contains(sys) ? sys : "en"
    }
    var rtl: Bool { false }
    var yon: LayoutDirection { .leftToRight }
    func t(_ key: String) -> String { (Yerel.S[key]?[aktif]) ?? (Yerel.S[key]?["en"]) ?? key }
    func u(_ alan: [String:String]) -> String { alan[aktif] ?? alan["en"] ?? alan["tr"] ?? "" }

    func sekmeAd(_ s: Sekme) -> String { t("sekme_" + s.rawValue) }
    func katAd(_ g: String) -> String { t("kat_" + g) }

    static let S: [String:[String:String]] = [
        "appAd": ["tr":"NickDegs Kurumsal","en":"NickDegs Business"],
        "hero1": ["tr":"İşletmenizin tüm gücü","en":"Everything your business needs"],
        "hero2": ["tr":"tek uygulamada","en":"in one app"],
        "heroAlt": ["tr":"İşletme çözümleri ve banka seviyesi güvenlik — NickDegs altyapısında.","en":"Business solutions and bank-grade security — on NickDegs infrastructure."],
        "ara": ["tr":"Hizmet ara…","en":"Search services…"],
        "incele": ["tr":"İncele & Satın Al","en":"View & Buy"],
        "webdeAc": ["tr":"Web'de Aç","en":"Open on Web"],
        "ozellikler": ["tr":"Öne çıkanlar","en":"Highlights"],
        "kapat": ["tr":"Kapat","en":"Close"],
        "sekme_isletme": ["tr":"İşletme","en":"Business"],
        "sekme_guvenlik": ["tr":"Güvenlik","en":"Security"],
        "sekme_hesabim": ["tr":"Hesabım","en":"My Account"],
        "kat_isletme": ["tr":"İşletme Çözümleri","en":"Business Solutions"],
        "kat_akilli": ["tr":"Akıllı Sistemler","en":"Smart Systems"],
        "kat_kurumsal": ["tr":"Kurumsal","en":"Enterprise"],
        "kat_guvenlik": ["tr":"Güvenlik","en":"Security"],
        // ayarlar
        "gorunumTema": ["tr":"Görünüm & Tema","en":"Appearance & Theme"],
        "gorunum": ["tr":"Görünüm","en":"Appearance"],
        "sistem": ["tr":"Sistem","en":"System"],
        "koyu": ["tr":"Koyu","en":"Dark"],
        "acik": ["tr":"Açık","en":"Light"],
        "renkTema": ["tr":"Renk Teması","en":"Color Theme"],
        "platformTema": ["tr":"Platform Teması","en":"Platform Theme"],
        "platformTemaAlt": ["tr":"İçerik ürettiğin platformun rengini seç","en":"Pick your platform's color"],
        "dil": ["tr":"Dil","en":"Language"],
        "dilAlt": ["tr":"Uygulama dilini seç","en":"Choose app language"],
        "dilSistem": ["tr":"Cihaz dili","en":"Device language"],
        "bitti": ["tr":"Bitti","en":"Done"],
        "nickdegsUrunu": ["tr":"Bir NickDegs ürünü","en":"A NickDegs product"],
        "magazaEyebrow": ["tr":"İşletme Mağazası","en":"Business Store"],
        "guvenlikEyebrow": ["tr":"Güvenlik Çözümleri","en":"Security Suite"],
        "oneCikan": ["tr":"Öne çıkan","en":"Featured"],
        "spotCta": ["tr":"Hemen başla","en":"Get started"],
        "tumu": ["tr":"Tümü","en":"All"],
    ]
}
