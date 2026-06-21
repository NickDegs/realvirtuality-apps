import SwiftUI

struct UrunDetayView: View {
    let urun: Urun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @State private var webAcik = false
    @State private var bel = false

    private var url: URL {
        let yol: String
        switch urun.sekme {
        case "bireysel": yol = "urunler"
        case "icerik":   yol = "dijital"
        default:          yol = "kurumsal"
        }
        return URL(string: "https://nickdegs.com/\(yol)?grup=\(urun.g)#\(urun.id)")!
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            LensFlare().opacity(0.8)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    baslik
                    if !urun.pr.isEmpty {
                        Text(urun.pr).font(.title3.bold()).foregroundStyle(tema.c2)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .glassEffect(.regular.tint(tema.c2.opacity(0.18)), in: .capsule)
                    }
                    Text(yerel.u(urun.aciklama))
                        .font(.callout).foregroundStyle(.rvText).opacity(0.95)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            VStack { Spacer(); cta }
        }
        .navigationTitle(yerel.u(urun.ad))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $webAcik) { PanelView(url: url, baslik: yerel.u(urun.ad)) }
        .onAppear { withAnimation(.smooth(duration: 0.5)) { bel = true } }
    }

    var baslik: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [tema.c1.opacity(0.28), tema.c2.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 70, height: 70)
                Text(urun.ic).font(.system(size: 36))
            }
            .scaleEffect(bel ? 1 : 0.8).opacity(bel ? 1 : 0)
            VStack(alignment: .leading, spacing: 5) {
                Text(yerel.u(urun.ad)).font(.title2.bold()).foregroundStyle(.rvText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(yerel.katAd(urun.g)).font(.caption).foregroundStyle(.rvMut)
            }
            Spacer(minLength: 0)
        }.padding(.top, 6)
    }

    var cta: some View {
        Button { webAcik = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                Text(yerel.t("incele"))
            }
            .font(.headline.bold()).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(tema.grad, in: .rect(cornerRadius: 20))
            .shadow(color: tema.c1.opacity(0.45), radius: 16, y: 7)
        }
        .padding(.horizontal, 16).padding(.bottom, 10)
    }
}
