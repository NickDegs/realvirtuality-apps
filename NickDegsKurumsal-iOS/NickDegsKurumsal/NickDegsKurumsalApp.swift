import SwiftUI
import StoreKit
import UserNotifications

// MARK: - APNs Push (işletme sahibine yeni sipariş/randevu bildirimi)
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
        let tok = UserDefaults.standard.string(forKey: "biz_panel_token") ?? ""
        guard !tok.isEmpty, let url = URL(string: "https://nickdegs.com/api/push/register") else { return }
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject:
            ["t": tok, "device_token": hex, "bundle": "com.nickdegs.business"])
        URLSession.shared.dataTask(with: r).resume()
    }
    func application(_ app: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}

func pushKaydet() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
        if granted { DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() } }
    }
}

// MARK: - Marka renkleri (Dark + Light adaptif)
extension Color {
    static let rvViolet = Color(red: 0.30, green: 0.42, blue: 1.0)    // kurumsal mavi
    static let rvCyan   = Color(red: 0.13, green: 0.78, blue: 0.85)
    static let rvBg = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(red: 0.039, green: 0.043, blue: 0.078, alpha: 1)
        : UIColor(red: 0.957, green: 0.969, blue: 1.0, alpha: 1) })
    static let rvBg2 = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1)
        : UIColor(red: 0.91, green: 0.93, blue: 1.0, alpha: 1) })
    static let rvCard = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(red: 0.078, green: 0.090, blue: 0.149, alpha: 1)
        : UIColor(red: 1, green: 1, blue: 1, alpha: 1) })
    static let rvLine = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.09) : UIColor(red: 0.83, green: 0.86, blue: 0.95, alpha: 1) })
    static let rvText = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(white: 0.96, alpha: 1) : UIColor(red: 0.06, green: 0.07, blue: 0.13, alpha: 1) })
    static let rvMut = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(red: 0.66, green: 0.70, blue: 0.80, alpha: 1) : UIColor(red: 0.42, green: 0.46, blue: 0.56, alpha: 1) })
}
extension ShapeStyle where Self == Color {
    static var rvViolet: Color { .rvViolet }; static var rvCyan: Color { .rvCyan }
    static var rvBg: Color { .rvBg }; static var rvCard: Color { .rvCard }
    static var rvText: Color { .rvText }; static var rvMut: Color { .rvMut }
}

// MARK: - Sekmeler (B2B: İşletme + Güvenlik + Hesabım)
enum Sekme: String, CaseIterable, Identifiable {
    case isletme, guvenlik, hesabim
    var id: String { rawValue }
    var ikon: String {
        switch self {
        case .isletme: return "building.2.fill"
        case .guvenlik: return "lock.shield.fill"
        case .hesabim: return "person.crop.circle.fill"
        }
    }
    var baslik: String {
        switch self {
        case .isletme: return "İşletme"
        case .guvenlik: return "Güvenlik"
        case .hesabim: return "Hesabım"
        }
    }
}

// MARK: - Ürün modeli (katalog.json)
struct Urun: Identifiable, Decodable {
    let id: String
    let sekme: String
    let g: String           // kategori
    let ic: String
    let ad: [String:String]
    let aciklama: [String:String]
    let pr: String
    let demo: String?
    func metin(_ alan: [String:String], _ dil: String) -> String {
        alan[dil] ?? alan["en"] ?? alan["tr"] ?? ""
    }
}

enum Katalog {
    static let urunler: [Urun] = {
        guard let u = Bundle.main.url(forResource: "katalog", withExtension: "json"),
              let d = try? Data(contentsOf: u),
              let a = try? JSONDecoder().decode([Urun].self, from: d) else { return [] }
        return a
    }()
    static let kategoriSira = ["bireysel","pro","sosyal","isletme","akilli","kurumsal","guvenlik"]
}

@main
struct NickDegsKurumsalApp: App {
    @UIApplicationDelegateAdaptor(PushDelegate.self) var pushDelegate
    @StateObject private var tema = Tema()
    @StateObject private var yerel = Yerel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tema)
                .environmentObject(yerel)
                .environment(\.layoutDirection, yerel.yon)
                .preferredColorScheme(tema.renkSemasi)
                .tint(tema.c1)
                .task { await AppAttest.shared.hazirla() }   // GÜVENLİK: donanım bütünlüğü (sideload/tamper engeli)
                .task { await bitmemisleriKurtar() }   // launch'ta bekleyen/kesintili abonelikler
                .task { await islemDinle() }
        }
    }

    // App açılışında bekleyen/bitmemiş transaction'ları süpür (uçuş modu, Ask to Buy,
    // Family Sharing, çökme sonrası, yenileme). Apple EK ÖNLEM (a).
    private func bitmemisleriKurtar() async {
        for await result in StoreKit.Transaction.unfinished {
            if case .verified(let tx) = result {
                // Sunucu provision/idempotent başarılıysa finish; değilse bırak, tekrar denenir.
                if await yenidenProvision(jws: result.jwsRepresentation) { await tx.finish() }
            }
        }
    }

    // Uçuş modu / çökme / yenileme sonrası bitmemiş transaction'ları kurtarır (canlı dinleyici)
    private func islemDinle() async {
        for await result in StoreKit.Transaction.updates {
            if case .verified(let tx) = result {
                // SADECE sunucu provision başarılıysa finish — yoksa abonelik aktif ama
                // tenant açılmamış kalır; bitirmeyince Apple tekrar teslim eder.
                if await yenidenProvision(jws: result.jwsRepresentation) { await tx.finish() }
            }
        }
    }

    private func yenidenProvision(jws: String) async -> Bool {
        guard let url = URL(string: "https://nickdegs.com/api/iap/provision") else { return false }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 60
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // ad boş göndeririz; sunucu önceki kaydı varsa adı kullanmadan döner
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["signedTransaction": jws, "ad": ""])
        guard let (d, _) = try? await URLSession.shared.data(for: r),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return false }
        return j["ok"] as? Bool == true
    }
}
