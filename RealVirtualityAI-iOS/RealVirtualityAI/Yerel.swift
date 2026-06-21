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

    // Ürün katalog metni (tr/en sözlük) — fallback en→tr
    func u(_ d: [String:String]) -> String { d[aktif] ?? d["en"] ?? d["tr"] ?? "" }
    // Sabit ürün-sekmesi metinleri (ui_i18n.json'da olmayanlar için)
    func p(_ key: String) -> String {
        let t = Yerel.urunUI[key] ?? [:]
        return t[aktif] ?? t["en"] ?? t["tr"] ?? key
    }
    static let urunUI: [String:[String:String]] = [
        "araclarTab": ["tr":"AI Araçları","en":"AI Tools","de":"KI-Tools","fr":"Outils IA","es":"Herramientas IA","ar":"أدوات الذكاء","ru":"AI Инструменты"],
        "urunlerTab": ["tr":"Ürünler","en":"Products","de":"Produkte","fr":"Produits","es":"Productos","ar":"المنتجات","ru":"Товары"],
        "urunHero1": ["tr":"Hazır dijital ürünler","en":"Ready digital products"],
        "urunHero2": ["tr":"& şablonlar","en":"& templates"],
        "urunAra": ["tr":"Ürün ara…","en":"Search products…"],
        "urunIncele": ["tr":"İncele & Satın Al","en":"View & Buy"],
        "kat_bireysel": ["tr":"Bireysel","en":"Personal"],
        "kat_pro": ["tr":"Pro / Freelancer","en":"Pro / Freelancer"],
        "kat_sosyal": ["tr":"Sosyal Medya","en":"Social Media"],
        "kutuphaneTab": ["tr":"Kütüphane","en":"Library","de":"Bibliothek","fr":"Bibliothèque","es":"Biblioteca","ar":"المكتبة","ru":"Библиотека"],
        "kutuphaneBaslik": ["tr":"Kütüphanem","en":"My Library","de":"Meine Bibliothek","fr":"Ma bibliothèque","es":"Mi biblioteca","ar":"مكتبتي","ru":"Моя библиотека"],
        "kutuphaneBos": ["tr":"Henüz çıktın yok. Bir araç kullan, üretimlerin burada saklanır.","en":"No outputs yet. Use a tool — your creations are saved here.","de":"Noch keine Ausgaben. Nutze ein Tool — deine Werke werden hier gespeichert.","fr":"Aucune sortie. Utilisez un outil — vos créations sont enregistrées ici.","es":"Sin resultados aún. Usa una herramienta — tus creaciones se guardan aquí.","ar":"لا مخرجات بعد. استخدم أداة — تُحفظ أعمالك هنا.","ru":"Пока нет результатов. Используйте инструмент — работы сохранятся здесь."],
        "kutuphaneGiris": ["tr":"Çıktıların kalıcı saklanması için giriş yap.","en":"Sign in to keep your outputs saved.","de":"Melde dich an, um deine Ausgaben zu speichern.","fr":"Connectez-vous pour conserver vos sorties.","es":"Inicia sesión para guardar tus resultados.","ar":"سجّل الدخول لحفظ مخرجاتك.","ru":"Войдите, чтобы сохранять результаты."],
        "tekrarYukle": ["tr":"Tekrar Yükle","en":"Reload","de":"Erneut laden","fr":"Recharger","es":"Recargar","ar":"إعادة تحميل","ru":"Загрузить снова"],
        "girisSms": ["tr":"SMS ile","en":"With SMS","de":"Mit SMS","fr":"Par SMS","es":"Con SMS","ar":"عبر SMS","ru":"Через SMS"],
        "girisEposta": ["tr":"E-posta ile","en":"With Email","de":"Mit E-Mail","fr":"Par e-mail","es":"Con correo","ar":"عبر البريد","ru":"Через e-mail"],
        "telefon": ["tr":"Telefon (ülke kodlu, +90…)","en":"Phone (with country code)","de":"Telefon (mit Ländercode)","fr":"Téléphone (indicatif pays)","es":"Teléfono (código de país)","ar":"الهاتف (رمز الدولة)","ru":"Телефон (код страны)"],
        "smsKodu": ["tr":"SMS kodu","en":"SMS code","de":"SMS-Code","fr":"Code SMS","es":"Código SMS","ar":"رمز SMS","ru":"SMS-код"],
        "kodGonder": ["tr":"Kod Gönder","en":"Send Code","de":"Code senden","fr":"Envoyer le code","es":"Enviar código","ar":"إرسال الرمز","ru":"Отправить код"],
        "dogrulaGiris": ["tr":"Doğrula & Giriş","en":"Verify & Sign In","de":"Bestätigen & Anmelden","fr":"Vérifier & Connexion","es":"Verificar e iniciar","ar":"تحقق ودخول","ru":"Подтвердить и войти"],
    ]

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
