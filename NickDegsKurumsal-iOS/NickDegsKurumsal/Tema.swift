import SwiftUI

// Seçilebilir renk paleti (accent)
struct Palet: Identifiable, Equatable {
    let id: String
    let ad: String
    let c1: Color
    let c2: Color
    var grup: String = "renk"   // "renk" veya "platform"
    var ikon: String? = nil     // platform paletleri için SF Symbol/etiket
    var grad: LinearGradient { LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing) }
}

private func H(_ hex: Int) -> Color {
    Color(red: Double((hex >> 16) & 0xff)/255, green: Double((hex >> 8) & 0xff)/255, blue: Double(hex & 0xff)/255)
}

let PALETLER: [Palet] = [
    Palet(id: "nickdegs", ad: "NickDegs", c1: H(0x4A86FF), c2: H(0xFFB43C)),
    // ── Renk temaları ──
    Palet(id: "mor",    ad: "Mor & Camgöbeği", c1: H(0x7C5CFF), c2: H(0x22D3EE)),
    Palet(id: "gun",    ad: "Gün Batımı",       c1: H(0xFF6B6B), c2: H(0xFFB74D)),
    Palet(id: "okyanus",ad: "Okyanus",          c1: H(0x338FFF), c2: H(0x22D9CC)),
    Palet(id: "orman",  ad: "Orman",            c1: H(0x2EC77F), c2: H(0x9BDB4D)),
    Palet(id: "gul",    ad: "Gül",              c1: H(0xF55CA8), c2: H(0x9E5CFF)),
    Palet(id: "altin",  ad: "Altın",            c1: H(0xF2B840), c2: H(0xFA734D)),
    Palet(id: "gece",   ad: "Gece Mavisi",      c1: H(0x5C75F2), c2: H(0x72B3FF)),
    Palet(id: "neon",   ad: "Neon",             c1: H(0xC633FF), c2: H(0x33F2A6)),
    // ── Platform temaları (içerik üreticisi kendi platformunu seçsin) ──
    Palet(id: "instagram", ad: "Instagram", c1: H(0xC13584), c2: H(0xF58529), grup: "platform", ikon: "camera.fill"),
    Palet(id: "facebook",  ad: "Facebook",  c1: H(0x1877F2), c2: H(0x4293FB), grup: "platform", ikon: "f.square.fill"),
    Palet(id: "x",         ad: "X (Twitter)",c1: H(0x1DA1F2), c2: H(0x0A85D9), grup: "platform", ikon: "bird.fill"),
    Palet(id: "tiktok",    ad: "TikTok",    c1: H(0xFE2C55), c2: H(0x25F4EE), grup: "platform", ikon: "music.note"),
    Palet(id: "youtube",   ad: "YouTube",   c1: H(0xFF0000), c2: H(0xFF5C5C), grup: "platform", ikon: "play.rectangle.fill"),
    Palet(id: "linkedin",  ad: "LinkedIn",  c1: H(0x0A66C2), c2: H(0x378FE9), grup: "platform", ikon: "briefcase.fill"),
    Palet(id: "whatsapp",  ad: "WhatsApp",  c1: H(0x25D366), c2: H(0x128C7E), grup: "platform", ikon: "phone.fill"),
    Palet(id: "telegram",  ad: "Telegram",  c1: H(0x2AABEE), c2: H(0x229ED9), grup: "platform", ikon: "paperplane.fill"),
]

@MainActor
final class Tema: ObservableObject {
    @AppStorage("tema_mod") var mod = "sistem" { didSet { objectWillChange.send() } }   // sistem/koyu/acik
    @AppStorage("tema_palet") var paletId = "nickdegs" { didSet { objectWillChange.send() } }

    var palet: Palet { PALETLER.first { $0.id == paletId } ?? PALETLER[0] }
    var c1: Color { palet.c1 }
    var c2: Color { palet.c2 }
    var grad: LinearGradient { palet.grad }
    var renkSemasi: ColorScheme? { mod == "koyu" ? .dark : mod == "acik" ? .light : nil }
}
