import SwiftUI

// MARK: - Mercek yanma (Lens Flare) — yavaşça dönen ışık parlaması
struct LensFlare: View {
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let x = CGFloat(cos(t * 0.18))   // çok yavaş gezinme
                let y = CGFloat(sin(t * 0.12))
                ZStack {
                    Circle().fill(.radialGradient(colors: [.rvViolet.opacity(0.45), .clear],
                                  center: .center, startRadius: 0, endRadius: 260))
                        .frame(width: 520).blur(radius: 90)
                        .offset(x: x * 150, y: -260 + y * 60)
                    Circle().fill(.radialGradient(colors: [.rvCyan.opacity(0.40), .clear],
                                  center: .center, startRadius: 0, endRadius: 230))
                        .frame(width: 460).blur(radius: 110)
                        .offset(x: -x * 130, y: 360 - y * 60)
                    Capsule().fill(.linearGradient(colors: [.clear, .white.opacity(0.10), .clear],
                                  startPoint: .leading, endPoint: .trailing))
                        .frame(width: 700, height: 3).blur(radius: 2)
                        .rotationEffect(.degrees(-22))
                        .offset(x: x * 200, y: y * 120)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Cam parıltısı (Liquid Glass üstünde kayan ışık)
struct ShimmerModifier: ViewModifier {
    @State private var kay: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { g in
                LinearGradient(colors: [.clear, .white.opacity(0.22), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: g.size.width * 1.5)
                    .offset(x: kay * g.size.width * 1.6)
                    .rotationEffect(.degrees(18))
                    .blendMode(.plusLighter)
                    .mask(content)
            }
            .allowsHitTesting(false)
        )
        .onAppear {
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false).delay(0.4)) { kay = 1.2 }
        }
    }
}
extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
    // Ultra yumuşak basış animasyonu
    func yumusakBas(_ basili: Bool) -> some View {
        scaleEffect(basili ? 0.96 : 1).animation(.spring(response: 0.32, dampingFraction: 0.65), value: basili)
    }
}

// Basıldığında yumuşak ölçeklenen buton sarmalı (ScrollView ile uyumlu — kaydırmayı engellemez)
struct BasilabilirKart<Content: View>: View {
    let aksiyon: () -> Void
    @ViewBuilder var content: () -> Content
    var body: some View {
        Button(action: { Haptik.orta(); aksiyon() }) { content() }
            .buttonStyle(BasiliStil())
    }
}
struct BasiliStil: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
enum Haptik {
    static func hafif() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func orta()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}
