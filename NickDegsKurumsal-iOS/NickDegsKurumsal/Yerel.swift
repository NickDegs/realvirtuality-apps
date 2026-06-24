import SwiftUI

// MARK: - Dil yönetimi (otomatik cihaz dili + manuel seçim)
@MainActor
final class Yerel: ObservableObject {
    static let diller = ["tr","en","de","fr","es","ar","ru"]
    static let dilAd: [String:String] = ["tr":"Türkçe","en":"English","de":"Deutsch","fr":"Français","es":"Español","ar":"العربية","ru":"Русский"]
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
        "appAd": ["tr":"NickDegs Kurumsal","en":"NickDegs Business","de":"NickDegs Business","fr":"NickDegs Business","es":"NickDegs Business","ar":"NickDegs Business","ru":"NickDegs Business"],
        "hero1": ["tr":"İşletmenizin tüm gücü","en":"Everything your business needs","de":"Alles für Ihr Unternehmen","fr":"Tout pour votre entreprise","es":"Todo para tu negocio","ar":"كل ما يحتاجه عملك","ru":"Всё для вашего бизнеса"],
        "hero2": ["tr":"tek uygulamada","en":"in one app","de":"in einer App","fr":"dans une seule app","es":"en una sola app","ar":"في تطبيق واحد","ru":"в одном приложении"],
        "heroAlt": ["tr":"İşletme çözümleri ve banka seviyesi güvenlik — NickDegs altyapısında.","en":"Business solutions and bank-grade security — on NickDegs infrastructure.","de":"Business-Lösungen und Sicherheit auf Bankniveau — auf der NickDegs-Infrastruktur.","fr":"Solutions professionnelles et sécurité de niveau bancaire — sur l'infrastructure NickDegs.","es":"Soluciones empresariales y seguridad de nivel bancario — en la infraestructura NickDegs.","ar":"حلول الأعمال وأمان بمستوى البنوك — على بنية NickDegs.","ru":"Бизнес-решения и банковская безопасность — на инфраструктуре NickDegs."],
        "ara": ["tr":"Hizmet ara…","en":"Search services…","de":"Dienste suchen…","fr":"Rechercher des services…","es":"Buscar servicios…","ar":"ابحث عن الخدمات…","ru":"Поиск услуг…"],
        "incele": ["tr":"İncele & Satın Al","en":"View & Buy","de":"Ansehen & Kaufen","fr":"Voir & Acheter","es":"Ver y Comprar","ar":"عرض وشراء","ru":"Смотреть и купить"],
        "webdeAc": ["tr":"Web'de Aç","en":"Open on Web","de":"Im Web öffnen","fr":"Ouvrir sur le Web","es":"Abrir en la Web","ar":"افتح على الويب","ru":"Открыть в вебе"],
        "ozellikler": ["tr":"Öne çıkanlar","en":"Highlights","de":"Highlights","fr":"Points forts","es":"Destacados","ar":"أبرز الميزات","ru":"Ключевые особенности"],
        "kapat": ["tr":"Kapat","en":"Close","de":"Schließen","fr":"Fermer","es":"Cerrar","ar":"إغلاق","ru":"Закрыть"],
        "sekme_isletme": ["tr":"İşletme","en":"Business","de":"Business","fr":"Entreprise","es":"Negocio","ar":"الأعمال","ru":"Бизнес"],
        "sekme_guvenlik": ["tr":"Güvenlik","en":"Security","de":"Sicherheit","fr":"Sécurité","es":"Seguridad","ar":"الأمان","ru":"Безопасность"],
        "sekme_hesabim": ["tr":"Hesabım","en":"My Account","de":"Mein Konto","fr":"Mon compte","es":"Mi cuenta","ar":"حسابي","ru":"Мой аккаунт"],
        "kat_isletme": ["tr":"İşletme Çözümleri","en":"Business Solutions","de":"Business-Lösungen","fr":"Solutions pro","es":"Soluciones de negocio","ar":"حلول الأعمال","ru":"Бизнес-решения"],
        "kat_akilli": ["tr":"Akıllı Sistemler","en":"Smart Systems","de":"Smarte Systeme","fr":"Systèmes intelligents","es":"Sistemas inteligentes","ar":"الأنظمة الذكية","ru":"Умные системы"],
        "kat_kurumsal": ["tr":"Kurumsal","en":"Enterprise","de":"Enterprise","fr":"Entreprise","es":"Corporativo","ar":"المؤسسات","ru":"Корпоративный"],
        "kat_guvenlik": ["tr":"Güvenlik","en":"Security","de":"Sicherheit","fr":"Sécurité","es":"Seguridad","ar":"الأمان","ru":"Безопасность"],
        // ayarlar
        "gorunumTema": ["tr":"Görünüm & Tema","en":"Appearance & Theme","de":"Darstellung & Thema","fr":"Apparence & Thème","es":"Apariencia y tema","ar":"المظهر والسمة","ru":"Вид и тема"],
        "gorunum": ["tr":"Görünüm","en":"Appearance","de":"Darstellung","fr":"Apparence","es":"Apariencia","ar":"المظهر","ru":"Вид"],
        "sistem": ["tr":"Sistem","en":"System","de":"System","fr":"Système","es":"Sistema","ar":"النظام","ru":"Система"],
        "koyu": ["tr":"Koyu","en":"Dark","de":"Dunkel","fr":"Sombre","es":"Oscuro","ar":"داكن","ru":"Тёмная"],
        "acik": ["tr":"Açık","en":"Light","de":"Hell","fr":"Clair","es":"Claro","ar":"فاتح","ru":"Светлая"],
        "renkTema": ["tr":"Renk Teması","en":"Color Theme","de":"Farbthema","fr":"Thème de couleur","es":"Tema de color","ar":"سمة الألوان","ru":"Цветовая тема"],
        "platformTema": ["tr":"Platform Teması","en":"Platform Theme","de":"Plattform-Thema","fr":"Thème de plateforme","es":"Tema de plataforma","ar":"سمة المنصة","ru":"Тема платформы"],
        "platformTemaAlt": ["tr":"İçerik ürettiğin platformun rengini seç","en":"Pick your platform's color","de":"Wähle die Farbe deiner Plattform","fr":"Choisis la couleur de ta plateforme","es":"Elige el color de tu plataforma","ar":"اختر لون منصتك","ru":"Выберите цвет вашей платформы"],
        "dil": ["tr":"Dil","en":"Language","de":"Sprache","fr":"Langue","es":"Idioma","ar":"اللغة","ru":"Язык"],
        "dilAlt": ["tr":"Uygulama dilini seç","en":"Choose app language","de":"App-Sprache wählen","fr":"Choisir la langue de l'app","es":"Elegir idioma de la app","ar":"اختر لغة التطبيق","ru":"Выберите язык приложения"],
        "dilSistem": ["tr":"Cihaz dili","en":"Device language","de":"Gerätesprache","fr":"Langue de l'appareil","es":"Idioma del dispositivo","ar":"لغة الجهاز","ru":"Язык устройства"],
        "bitti": ["tr":"Bitti","en":"Done","de":"Fertig","fr":"Terminé","es":"Listo","ar":"تم","ru":"Готово"],
        "nickdegsUrunu": ["tr":"Bir NickDegs ürünü","en":"A NickDegs product","de":"Ein NickDegs-Produkt","fr":"Un produit NickDegs","es":"Un producto NickDegs","ar":"منتج من NickDegs","ru":"Продукт NickDegs"],
        "magazaEyebrow": ["tr":"İşletme Mağazası","en":"Business Store","de":"Business-Store","fr":"Boutique pro","es":"Tienda de negocio","ar":"متجر الأعمال","ru":"Бизнес-магазин"],
        "guvenlikEyebrow": ["tr":"Güvenlik Çözümleri","en":"Security Suite","de":"Sicherheitspaket","fr":"Suite sécurité","es":"Paquete de seguridad","ar":"حزمة الأمان","ru":"Пакет безопасности"],
        "oneCikan": ["tr":"Öne çıkan","en":"Featured","de":"Empfohlen","fr":"En vedette","es":"Destacado","ar":"مميّز","ru":"Рекомендуем"],
        "spotCta": ["tr":"Hemen başla","en":"Get started","de":"Loslegen","fr":"Commencer","es":"Empezar","ar":"ابدأ الآن","ru":"Начать"],
        "tumu": ["tr":"Tümü","en":"All","de":"Alle","fr":"Tout","es":"Todo","ar":"الكل","ru":"Все"],
    ]
}
