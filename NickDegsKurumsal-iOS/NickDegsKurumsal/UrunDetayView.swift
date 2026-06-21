import SwiftUI

struct UrunDetayView: View {
    let urun: Urun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @State private var webAcik = false

    // Ürünün web'deki sayfası (sekmeye göre katalog + grup filtresi)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    baslik
                    if !urun.pr.isEmpty {
                        Text(urun.pr).font(.title3.bold()).foregroundStyle(tema.c2)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(tema.c2.opacity(0.12), in: .capsule)
                    }
                    Text(yerel.u(urun.aciklama))
                        .font(.callout).foregroundStyle(.rvText).opacity(0.92)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.rvCard, in: .rect(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.rvLine, lineWidth: 1))
                    Color.clear.frame(height: 70)
                }
                .padding(.horizontal, 16).padding(.top, 6)
            }
            VStack { Spacer(); cta }
        }
        .navigationTitle(yerel.u(urun.ad))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $webAcik) { PanelView(url: url, baslik: yerel.u(urun.ad)) }
    }

    var baslik: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [tema.c1.opacity(0.22), tema.c2.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Text(urun.ic).font(.system(size: 32))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(yerel.u(urun.ad)).font(.title2.bold()).foregroundStyle(.rvText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(yerel.katAd(urun.g)).font(.caption).foregroundStyle(.rvMut)
            }
            Spacer(minLength: 0)
        }.padding(.top, 4)
    }

    var cta: some View {
        Button { webAcik = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                Text(yerel.t("incele"))
            }
            .font(.headline.bold()).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(tema.grad, in: .rect(cornerRadius: 18))
            .shadow(color: tema.c1.opacity(0.4), radius: 14, y: 6)
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }
}
