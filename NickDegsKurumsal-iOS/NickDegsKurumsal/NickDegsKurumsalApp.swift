import SwiftUI

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
        case .hesabim: return "bag.fill.badge.checkmark"
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
        }
    }
}
