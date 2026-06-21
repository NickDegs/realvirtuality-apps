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

// Basıldığında yumuşak ölçeklenen + haptik buton sarmalı
struct BasilabilirKart<Content: View>: View {
    @GestureState private var basili = false
    let aksiyon: () -> Void
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .scaleEffect(basili ? 0.95 : 1)
            .brightness(basili ? 0.04 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: basili)
            .onChange(of: basili) { _, yeni in if yeni { Haptik.hafif() } }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($basili) { _, s, _ in s = true }
                    .onEnded { _ in Haptik.orta(); aksiyon() }
            )
    }
}

// Haptik geri bildirim
enum Haptik {
    static func hafif() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func orta()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}

// Cam parıltısı (glow) — öne çıkan kartlar için
struct GlowModifier: ViewModifier {
    let renk: Color
    @State private var nabiz = false
    func body(content: Content) -> some View {
        content
            .shadow(color: renk.opacity(nabiz ? 0.45 : 0.2), radius: nabiz ? 22 : 12)
            .onAppear { withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { nabiz = true } }
    }
}

// Yavaş animasyonlu gradyan arka plan — ultra premium his
struct AnimatedArka: View {
    let c1: Color; let c2: Color
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let x = CGFloat(cos(t * 0.07)) * 0.4
            let y = CGFloat(sin(t * 0.05)) * 0.4
            ZStack {
                LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [c1.opacity(0.18), .clear], center: UnitPoint(x: 0.5 + x, y: 0.25 + y), startRadius: 0, endRadius: 420)
                RadialGradient(colors: [c2.opacity(0.14), .clear], center: UnitPoint(x: 0.5 - x, y: 0.8 - y), startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
        }
    }
}
extension View {
    func parlak(_ renk: Color) -> some View { modifier(GlowModifier(renk: renk)) }
}
