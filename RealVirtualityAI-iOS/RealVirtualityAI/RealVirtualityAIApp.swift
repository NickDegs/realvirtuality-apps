import SwiftUI

// Marka renkleri
extension Color {
    static let rvBg = Color(red: 0.039, green: 0.043, blue: 0.078)   // #0a0b14
    static let rvViolet = Color(red: 0.486, green: 0.361, blue: 1.0)  // #7c5cff
    static let rvCyan = Color(red: 0.133, green: 0.827, blue: 0.933)  // #22d3ee
    static let rvCard = Color(red: 0.078, green: 0.090, blue: 0.149)  // #141726
}
// .foregroundStyle(.rvCyan) / .fill(.rvViolet) / .tint(.rvBg) gibi ShapeStyle bağlamlarında kısa kullanım
extension ShapeStyle where Self == Color {
    static var rvBg: Color { Color.rvBg }
    static var rvViolet: Color { Color.rvViolet }
    static var rvCyan: Color { Color.rvCyan }
    static var rvCard: Color { Color.rvCard }
}

// Araç tanımı
struct Arac: Identifiable {
    let id: String
    let ikon: String      // SF Symbol
    let ad: String
    let aciklama: String
    let kind: Kind        // giriş türü
    let kredi: Int
    enum Kind { case prompt, metin, ceviri, gorselYukle }
}

let ARACLAR: [Arac] = [
    Arac(id: "gorsel", ikon: "photo.artframe", ad: "AI Görsel Üret", aciklama: "Yazıdan görsel (FLUX)", kind: .prompt, kredi: 6),
    Arac(id: "yazi", ikon: "pencil.and.scribble", ad: "Yazı Asistanı", aciklama: "Metin yaz / özetle", kind: .metin, kredi: 2),
    Arac(id: "ceviri", ikon: "character.bubble", ad: "Çeviri", aciklama: "7+ dile çevir", kind: .ceviri, kredi: 1),
    Arac(id: "sohbet", ikon: "bubble.left.and.bubble.right", ad: "AI Sohbet", aciklama: "Her şeyi sor", kind: .metin, kredi: 1),
    Arac(id: "seo", ikon: "magnifyingglass", ad: "SEO & Kelime", aciklama: "Başlık + anahtar kelime", kind: .metin, kredi: 2),
    Arac(id: "kod", ikon: "chevron.left.forwardslash.chevron.right", ad: "Kod Asistanı", aciklama: "Kod yaz / düzelt", kind: .metin, kredi: 2),
    Arac(id: "logo", ikon: "seal", ad: "Logo Üret", aciklama: "Markana logo", kind: .prompt, kredi: 6),
]

@main
struct RealVirtualityAIApp: App {
    @StateObject private var api = API()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .preferredColorScheme(.dark)
                .task { await api.durumYukle() }
        }
    }
}
