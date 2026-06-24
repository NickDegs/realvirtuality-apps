import SwiftUI

// MARK: - Mercek yanma (Lens Flare) — ultra yumuşak, çok katmanlı ışık
struct LensFlare: View {
    var c1: Color = .rvViolet
    var c2: Color = .rvCyan
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                // düşük frekanslı, faz-kaymalı sinüsler → ultra yumuşak gezinme + nefes alma
                let breathe = CGFloat(1 + 0.07 * sin(t * 0.45))
                let a1x = CGFloat(cos(t * 0.13)),       a1y = CGFloat(sin(t * 0.11))
                let a2x = CGFloat(cos(t * 0.09 + 2.1)), a2y = CGFloat(sin(t * 0.10 + 1.3))
                let a3x = CGFloat(cos(t * 0.17 + 4.0)), a3y = CGFloat(sin(t * 0.07 + 0.6))
                let w = geo.size.width
                ZStack {
                    orb(c1, 0.42, 280).frame(width: 540 * breathe).blur(radius: 90)
                        .offset(x: a1x * 150, y: -250 + a1y * 70)
                    orb(c2, 0.38, 250).frame(width: 480 * breathe).blur(radius: 110)
                        .offset(x: -a2x * 140, y: 350 - a2y * 70)
                    orb(.white, 0.18, 90).frame(width: 150 * breathe).blur(radius: 42)
                        .offset(x: a3x * 120, y: -110 + a3y * 170)
                    streakLine(w * 1.7)
                        .rotationEffect(.degrees(-22 + 6 * sin(t * 0.2)))
                        .offset(x: a1x * 200, y: a1y * 120)
                    streakLine(w * 1.2).opacity(0.5)
                        .rotationEffect(.degrees(14 + 4 * cos(t * 0.18)))
                        .offset(x: -a2x * 160, y: 60 + a2y * 100)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
    private func orb(_ c: Color, _ op: Double, _ r: CGFloat) -> some View {
        Circle().fill(.radialGradient(colors: [c.opacity(op), .clear],
                      center: .center, startRadius: 0, endRadius: r))
    }
    private func streakLine(_ width: CGFloat) -> some View {
        Capsule().fill(.linearGradient(colors: [.clear, .white.opacity(0.12), .clear],
                       startPoint: .leading, endPoint: .trailing))
            .frame(width: width, height: 3).blur(radius: 2).blendMode(.plusLighter)
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
