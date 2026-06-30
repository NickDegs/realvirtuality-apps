import SwiftUI
import StoreKit
import UserNotifications
import UIKit

// MARK: - Marka renkleri (Dark + Light uyumlu / adaptif)
extension Color {
    static let rvViolet = Color(red: 0.486, green: 0.361, blue: 1.0)   // #7c5cff (her iki temada aynı)
    static let rvCyan   = Color(red: 0.133, green: 0.827, blue: 0.933) // #22d3ee

    // Arka plan — dark: koyu lacivert, light: çok açık gri-mavi
    static let rvBg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.039, green: 0.043, blue: 0.078, alpha: 1)
            : UIColor(red: 0.957, green: 0.969, blue: 1.0, alpha: 1) })
    // İkincil arka plan (hero/section)
    static let rvBg2 = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.05, blue: 0.18, alpha: 1)
            : UIColor(red: 0.91, green: 0.93, blue: 1.0, alpha: 1) })
    // Kart yüzeyi
    static let rvCard = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.090, blue: 0.149, alpha: 1)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 1) })
    // Kart kenarlığı
    static let rvLine = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.09)
            : UIColor(red: 0.83, green: 0.86, blue: 0.95, alpha: 1) })
    // Ana metin
    static let rvText = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.96, alpha: 1) : UIColor(red: 0.06, green: 0.07, blue: 0.13, alpha: 1) })
    // İkincil metin
    static let rvMut = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.66, green: 0.70, blue: 0.80, alpha: 1) : UIColor(red: 0.42, green: 0.46, blue: 0.56, alpha: 1) })
}
extension ShapeStyle where Self == Color {
    static var rvViolet: Color { .rvViolet }
    static var rvCyan: Color { .rvCyan }
    static var rvBg: Color { .rvBg }
    static var rvCard: Color { .rvCard }
    static var rvText: Color { .rvText }
    static var rvMut: Color { .rvMut }
}
// Marka gradyanı kısayolu
extension LinearGradient {
    static let marka = LinearGradient(colors: [.rvViolet, .rvCyan], startPoint: .leading, endPoint: .trailing)
}

// MARK: - Araç giriş türleri
enum AracKind { case prompt, metin, ceviri, gorselYukle, gorselArti, urunfoto, icerik, url, ses, faceswap, pdf, video }

// MARK: - Kategori
enum Kategori: String, CaseIterable, Identifiable {
    case gorsel, video, ses, icerik, analiz
    var id: String { rawValue }
    var key: String { "kat_" + rawValue }   // Yerel anahtarı
    var ikon: String {
        switch self {
        case .gorsel: return "paintbrush.pointed.fill"
        case .video: return "film.fill"
        case .ses: return "waveform"
        case .icerik: return "text.word.spacing"
        case .analiz: return "doc.viewfinder"
        }
    }
}

// MARK: - Araç tanımı (yapısal; metinler Yerel'den çok dilli gelir)
struct Arac: Identifiable, Hashable {
    let id: String
    let ikon: String
    let kind: AracKind
    let kredi: Int
    let kategori: Kategori
    var oneCikan: Bool = false
    static func == (l: Arac, r: Arac) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

let ARACLAR: [Arac] = [
    // Görsel & Tasarım
    Arac(id: "urunfoto", ikon: "camera.aperture", kind: .urunfoto, kredi: 7, kategori: .gorsel, oneCikan: true),
    Arac(id: "gorsel", ikon: "photo.artframe", kind: .prompt, kredi: 5, kategori: .gorsel, oneCikan: true),
    Arac(id: "logo", ikon: "seal.fill", kind: .prompt, kredi: 5, kategori: .gorsel),
    Arac(id: "donustur", ikon: "wand.and.stars", kind: .gorselArti, kredi: 5, kategori: .gorsel),
    Arac(id: "upscale", ikon: "arrow.up.left.and.arrow.down.right", kind: .gorselYukle, kredi: 3, kategori: .gorsel),
    Arac(id: "bgremove", ikon: "scissors", kind: .gorselYukle, kredi: 2, kategori: .gorsel),
    Arac(id: "faceswap", ikon: "person.2.crop.square.stack.fill", kind: .faceswap, kredi: 6, kategori: .gorsel, oneCikan: true),
    Arac(id: "tryon", ikon: "tshirt.fill", kind: .faceswap, kredi: 8, kategori: .gorsel, oneCikan: true),
    Arac(id: "duzenle", ikon: "wand.and.rays", kind: .gorselArti, kredi: 7, kategori: .gorsel, oneCikan: true),
    Arac(id: "bgreplace", ikon: "person.and.background.dotted", kind: .gorselArti, kredi: 7, kategori: .gorsel),
    Arac(id: "restore", ikon: "sparkle.magnifyingglass", kind: .gorselYukle, kredi: 4, kategori: .gorsel),
    Arac(id: "superupscale", ikon: "arrow.up.backward.and.arrow.down.forward.circle.fill", kind: .gorselYukle, kredi: 7, kategori: .gorsel),
    Arac(id: "relight", ikon: "lightbulb.max.fill", kind: .gorselArti, kredi: 5, kategori: .gorsel),
    Arac(id: "anime", ikon: "theatermasks.fill", kind: .gorselYukle, kredi: 4, kategori: .gorsel),
    Arac(id: "sticker", ikon: "face.smiling.inverse", kind: .gorselYukle, kredi: 4, kategori: .gorsel),
    Arac(id: "ideogram", ikon: "textformat.abc.dottedunderline", kind: .prompt, kredi: 14, kategori: .gorsel, oneCikan: true),
    Arac(id: "fluxpro", ikon: "sparkles.tv.fill", kind: .prompt, kredi: 9, kategori: .gorsel, oneCikan: true),
    Arac(id: "recraft", ikon: "pencil.and.ruler.fill", kind: .prompt, kredi: 7, kategori: .gorsel),
    Arac(id: "renklendir", ikon: "paintpalette.fill", kind: .gorselYukle, kredi: 4, kategori: .gorsel),
    Arac(id: "genislet", ikon: "arrow.left.and.right.square.fill", kind: .gorselYukle, kredi: 7, kategori: .gorsel),
    // İçerik & Yazı
    Arac(id: "icerik", ikon: "sparkles.rectangle.stack", kind: .icerik, kredi: 6, kategori: .icerik, oneCikan: true),
    Arac(id: "pro", ikon: "brain.head.profile", kind: .metin, kredi: 3, kategori: .icerik, oneCikan: true),
    Arac(id: "yazi", ikon: "pencil.and.scribble", kind: .metin, kredi: 2, kategori: .icerik),
    Arac(id: "ceviri", ikon: "character.bubble.fill", kind: .ceviri, kredi: 1, kategori: .icerik),
    Arac(id: "seo", ikon: "magnifyingglass", kind: .metin, kredi: 2, kategori: .icerik),
    Arac(id: "sohbet", ikon: "bubble.left.and.bubble.right.fill", kind: .metin, kredi: 1, kategori: .icerik),
    Arac(id: "kod", ikon: "chevron.left.forwardslash.chevron.right", kind: .metin, kredi: 2, kategori: .icerik),
    // Video
    Arac(id: "video", ikon: "film.fill", kind: .prompt, kredi: 25, kategori: .video, oneCikan: true),
    Arac(id: "hdvideo", ikon: "film.stack.fill", kind: .prompt, kredi: 84, kategori: .video, oneCikan: true),
    Arac(id: "img2video", ikon: "photo.badge.arrow.down.fill", kind: .gorselYukle, kredi: 17, kategori: .video, oneCikan: true),
    Arac(id: "avatar", ikon: "person.crop.rectangle.badge.plus", kind: .gorselArti, kredi: 17, kategori: .video, oneCikan: true),
    Arac(id: "klip", ikon: "scissors.badge.ellipsis", kind: .video, kredi: 5, kategori: .video, oneCikan: true),
    // Ses
    Arac(id: "muzik", ikon: "music.note", kind: .prompt, kredi: 9, kategori: .ses, oneCikan: true),
    Arac(id: "tts", ikon: "speaker.wave.3.fill", kind: .metin, kredi: 2, kategori: .ses),
    Arac(id: "transkript", ikon: "waveform.and.mic", kind: .url, kredi: 3, kategori: .ses),
    // Görsel Zekâ & Belge
    Arac(id: "aciklama", ikon: "text.below.photo.fill", kind: .gorselYukle, kredi: 2, kategori: .analiz),
    Arac(id: "vsoru", ikon: "questionmark.bubble.fill", kind: .gorselArti, kredi: 2, kategori: .analiz),
    Arac(id: "ocr", ikon: "doc.text.viewfinder", kind: .gorselYukle, kredi: 2, kategori: .analiz),
    Arac(id: "pdfozet", ikon: "doc.text.magnifyingglass", kind: .pdf, kredi: 3, kategori: .analiz),
]

// MARK: - App
struct RootView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @State private var seciliTab = 0
    @State private var onboarding = !UserDefaults.standard.bool(forKey: "rv_onboarding_v1")
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView(selection: $seciliTab) {
            KategoriView(katlar: [.gorsel], baslik: yerel.t("kat_gorsel"), ikon: Kategori.gorsel.ikon)
                .tabItem { Label(yerel.p("gorselTab"), systemImage: Kategori.gorsel.ikon) }.tag(0)
            KategoriView(katlar: [.video], baslik: yerel.t("kat_video"), ikon: Kategori.video.ikon)
                .tabItem { Label(yerel.p("videoTab"), systemImage: Kategori.video.ikon) }.tag(1)
            KategoriView(katlar: [.ses], baslik: yerel.t("kat_ses"), ikon: Kategori.ses.ikon)
                .tabItem { Label(yerel.p("sesTab"), systemImage: Kategori.ses.ikon) }.tag(2)
            KategoriView(katlar: [.icerik, .analiz], baslik: yerel.t("kat_icerik"), ikon: Kategori.icerik.ikon)
                .tabItem { Label(yerel.p("yaziTab"), systemImage: Kategori.icerik.ikon) }.tag(3)
            KutuphaneView()
                .tabItem { Label(yerel.p("kutuphaneTab"), systemImage: "books.vertical.fill") }.tag(4)
            // App Store Guideline 3.1.1: harici-ödemeli dijital ürün satışı YASAK.
            // Ürünler sekmesi yalnızca URUNLER_TAB derleme bayrağı tanımlıysa görünür (App Store/TestFlight'ta KAPALI).
            // Para kazanma kredi-IAP ile (ContentView başlık + ToolView) → 3.1.1 uyumlu.
            #if URUNLER_TAB
            UrunlerView()
                .tabItem { Label(yerel.p("urunlerTab"), systemImage: "bag.fill") }.tag(5)
            #endif
        }
        .tint(tema.c1)
        // Siri/Kısayollar bekleyen sekme isteği → ilgili sekmeye geç (App Intents köprüsü)
        .onAppear { if let t = RVNav.bekleyen() { seciliTab = t } }
        .onChange(of: scenePhase) { _, yeni in
            if yeni == .active, let t = RVNav.bekleyen() { seciliTab = t }
        }
        // Widget / deep-link (rvai://…) → ilgili sekme
        .onOpenURL { url in
            switch url.host {
            case "gorsel": seciliTab = 0
            case "video", "klip": seciliTab = 1
            case "ses", "studyo", "seslendirme", "muzik": seciliTab = 2
            case "icerik": seciliTab = 3
            case "kutuphane": seciliTab = 4
            default: break
            }
        }
        .fullScreenCover(isPresented: $onboarding) {
            OnboardingView(goster: $onboarding).environmentObject(tema).environmentObject(yerel)
        }
        .task { if !onboarding { await pushIzniIste() } }
        .onChange(of: onboarding) { _, yeni in if !yeni { Task { await pushIzniIste() } } }
    }

    // Bildirim izni iste + uzak bildirime kaydol (onboarding bitince → değer görülmüş olur)
    func pushIzniIste() async {
        let merkez = UNUserNotificationCenter.current()
        if let izin = try? await merkez.requestAuthorization(options: [.alert, .sound, .badge]), izin {
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
}

// MARK: - Push bildirim (günlük kredi/yeni özellik hatırlatması)
final class PushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ app: UIApplication, didFinishLaunchingWithOptions o: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
        h([.banner, .sound, .badge])
    }
    func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive r: UNNotificationResponse,
                                withCompletionHandler h: @escaping () -> Void) { h() }
    func application(_ app: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: "rv_push_token")
        Task { await API.shared?.pushKaydet() }
    }
    func application(_ app: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}

// MARK: - Screenshot modu (App Store IAP/paywall görselleri — CI simülatör capture, SS_MODE=1)
// Yalnızca CI screenshot çekiminde aktif (env SS_MODE=1). Gerçek kullanıcıyı/üretimi ETKİLEMEZ.
enum RVShot {
    static let aktif = ProcessInfo.processInfo.environment["SS_MODE"] == "1"
    struct Paket: Identifiable { let id: String; let ad: String; let aciklama: String; let fiyat: String }
    static let paketler = [
        Paket(id: "250",  ad: "250 Kredi",   aciklama: "Başlangıç paketi", fiyat: "$7.99"),
        Paket(id: "750",  ad: "750 Kredi",   aciklama: "En popüler",       fiyat: "$18.99"),
        Paket(id: "2500", ad: "2.500 Kredi", aciklama: "Avantajlı",        fiyat: "$42.99"),
        Paket(id: "7000", ad: "7.000 Kredi", aciklama: "En iyi değer",     fiyat: "$99.99"),
    ]
    @MainActor static func mockGiris(_ api: API) {
        api.girisli = true
        api.email = "review@nickdegs.com"
        api.kredi = 1250
    }
}

@main
struct RealVirtualityAIApp: App {
    @UIApplicationDelegateAdaptor(PushDelegate.self) var pushDelegate
    @StateObject private var api = API()
    @StateObject private var tema = Tema()
    @StateObject private var yerel = Yerel()
    @StateObject private var tercih = RVTercih()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(api)
                .environmentObject(tema)
                .environmentObject(yerel)
                .environmentObject(tercih)
                .environment(\.layoutDirection, yerel.yon)
                .preferredColorScheme(tema.renkSemasi)
                .tint(tema.c1)
                .task { if RVShot.aktif { RVShot.mockGiris(api) } else { await api.durumYukle() } }
                .task { await bitmemisleriKurtar() }   // launch'ta bekleyen/kesintili satın almalar
                .task { await islemDinle() }
        }
    }

    // App açılışında bekleyen/bitmemiş transaction'ları süpür (uçuş modu, Ask to Buy,
    // Family Sharing, çökme sonrası). Apple EK ÖNLEM (a).
    private func bitmemisleriKurtar() async {
        for await result in StoreKit.Transaction.unfinished {
            if case .verified(let tx) = result {
                if await api.iapDogrula(jws: result.jwsRepresentation) == nil {
                    await tx.finish()
                }
            }
        }
    }

    // Family Sharing / Ask to Buy onayı / çökme recovery (canlı dinleyici)
    private func islemDinle() async {
        for await result in StoreKit.Transaction.updates {
            if case .verified(let tx) = result {
                // SADECE sunucu doğrulaması başarılıysa finish et — yoksa kredi kaybolur.
                if await api.iapDogrula(jws: result.jwsRepresentation) == nil {
                    await tx.finish()
                }
            }
        }
    }
}
