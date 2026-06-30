import SwiftUI

// MARK: - İlk açılış rehberi (3 sayfa) — uygulamayı tanıtır, "Başla" ile kapanır
struct OnboardingView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Binding var goster: Bool
    @State private var sayfa = 0

    struct Sayfa { let ikon: String; let baslik: String; let alt: String }
    var sayfalar: [Sayfa] {
        [Sayfa(ikon: "sparkles", baslik: yerel.t("obBaslik1"), alt: yerel.t("obAlt1")),
         Sayfa(ikon: "wand.and.stars", baslik: yerel.t("obBaslik2"), alt: yerel.t("obAlt2")),
         Sayfa(ikon: "gift.fill", baslik: yerel.t("obBaslik3"), alt: yerel.t("obAlt3"))]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(yerel.t("obAtla")) { kapat() }.font(.subheadline).foregroundStyle(.rvMut).padding()
                }
                TabView(selection: $sayfa) {
                    ForEach(Array(sayfalar.enumerated()), id: \.offset) { i, s in
                        VStack(spacing: 26) {
                            Spacer()
                            ZStack {
                                Circle().fill(tema.c1.opacity(0.15)).frame(width: 150, height: 150)
                                Image(systemName: s.ikon).font(.system(size: 64, weight: .semibold)).foregroundStyle(tema.grad)
                            }
                            Text(s.baslik).font(.title.bold()).foregroundStyle(.rvText).multilineTextAlignment(.center)
                            Text(s.alt).font(.body).foregroundStyle(.rvMut).multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 30)
                            Spacer()
                        }.tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if sayfa < sayfalar.count - 1 { withAnimation { sayfa += 1 } } else { kapat() }
                } label: {
                    Text(sayfa < sayfalar.count - 1 ? yerel.t("obBasla") : yerel.t("obBasla"))
                        .font(.headline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(tema.grad, in: .rect(cornerRadius: 16))
                        .shadow(color: tema.c1.opacity(0.4), radius: 14, y: 6)
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
            }
        }
    }

    func kapat() {
        UserDefaults.standard.set(true, forKey: "rv_onboarding_v1")
        withAnimation { goster = false }
    }
}
