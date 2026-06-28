import SwiftUI

// Liquid Glass (iOS 26) — eski cihazlarda (iOS 17+) zarif material fallback.
// Tüm .glassEffect(...) çağrıları .rvGlass(...) ile değiştirildi → tek yerden availability yönetimi.
extension View {
    @ViewBuilder
    func rvGlass(_ radius: CGFloat = 16, capsule: Bool = false, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            modifier(RVGlass26(radius: radius, capsule: capsule, tint: tint, interactive: interactive))
        } else {
            modifier(RVGlassFallback(radius: radius, capsule: capsule, tint: tint))
        }
    }
}

@available(iOS 26.0, *)
private struct RVGlass26: ViewModifier {
    let radius: CGFloat; let capsule: Bool; let tint: Color?; let interactive: Bool
    func body(content: Content) -> some View {
        var g: Glass = .regular
        if interactive { g = g.interactive() }
        if let t = tint { g = g.tint(t) }
        if capsule {
            return AnyView(content.glassEffect(g, in: .capsule))
        } else {
            return AnyView(content.glassEffect(g, in: .rect(cornerRadius: radius)))
        }
    }
}

// iOS 17–25: ultraThinMaterial + opsiyonel tint + ince kenarlık → "cam" hissi.
private struct RVGlassFallback: ViewModifier {
    let radius: CGFloat; let capsule: Bool; let tint: Color?
    func body(content: Content) -> some View {
        let shape: AnyShape = capsule
            ? AnyShape(Capsule())
            : AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        return content
            .background(.ultraThinMaterial, in: shape)
            .overlay { if let t = tint { shape.fill(t) } }
            .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}
