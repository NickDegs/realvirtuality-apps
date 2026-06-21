import SwiftUI

// MARK: - Marka renkleri (Dark + Light adaptif, kurumsal mavi)
extension Color {
    static let rvViolet = Color(red: 0.30, green: 0.42, blue: 1.0)
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

// MARK: - Oturum (işletme tenant girişi)
@MainActor
final class Oturum: ObservableObject {
    @AppStorage("panel_token") var token = ""
    @AppStorage("panel_host") var host = "https://nickdegs.com"
    @Published var girisli = false
    init() { girisli = !token.isEmpty }
    func girisYap(token: String) { self.token = token; girisli = true }
    func cikis() { token = ""; girisli = false }
}

@main
struct NickDegsPanelApp: App {
    @StateObject private var tema = Tema()
    @StateObject private var oturum = Oturum()
    var body: some Scene {
        WindowGroup {
            Group {
                if oturum.girisli { MainView() }
                else { LoginView() }
            }
            .environmentObject(tema)
            .environmentObject(oturum)
            .preferredColorScheme(tema.renkSemasi)
            .tint(tema.c1)
        }
    }
}
