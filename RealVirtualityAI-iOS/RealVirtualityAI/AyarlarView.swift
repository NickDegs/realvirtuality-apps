import SwiftUI

struct AyarlarView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Environment(\.dismiss) var dismiss

    var modlar: [(String,String,String)] {
        [("sistem",yerel.t("sistem"),"circle.lefthalf.filled"), ("koyu",yerel.t("koyu"),"moon.fill"), ("acik",yerel.t("acik"),"sun.max.fill")]
    }
    let kolon = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        onizleme
                        dilBolumu
                        // Görünüm modu
                        VStack(alignment: .leading, spacing: 10) {
                            Text(yerel.t("gorunum")).font(.headline).foregroundStyle(.rvText)
                            HStack(spacing: 10) {
                                ForEach(modlar, id: \.0) { m in
                                    Button { withAnimation(.snappy) { tema.mod = m.0 } } label: {
                                        VStack(spacing: 7) {
                                            Image(systemName: m.2).font(.title3)
                                            Text(m.1).font(.caption.bold())
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                                        .foregroundStyle(tema.mod == m.0 ? .white : Color.rvText)
                                        .background(tema.mod == m.0 ? AnyShapeStyle(tema.grad) : AnyShapeStyle(Color.rvCard), in: .rect(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvLine, lineWidth: tema.mod == m.0 ? 0 : 1))
                                    }
                                }
                            }
                        }
                        // Renk teması galerisi
                        VStack(alignment: .leading, spacing: 12) {
                            Text(yerel.t("renkTema")).font(.headline).foregroundStyle(.rvText)
                            LazyVGrid(columns: kolon, spacing: 12) {
                                ForEach(PALETLER.filter { $0.grup == "renk" }) { p in paletKart(p) }
                            }
                        }
                        // Platform temaları
                        VStack(alignment: .leading, spacing: 6) {
                            Text(yerel.t("platformTema")).font(.headline).foregroundStyle(.rvText)
                            Text(yerel.t("platformTemaAlt")).font(.caption).foregroundStyle(.rvMut)
                            LazyVGrid(columns: kolon, spacing: 12) {
                                ForEach(PALETLER.filter { $0.grup == "platform" }) { p in paletKart(p) }
                            }
                            .padding(.top, 6)
                        }
                    }
                    // Gizlilik & Kullanım Koşulları
                    HStack(spacing: 16) {
                        Link(yerel.p("gizlilikPolitikasi"), destination: URL(string: "https://nickdegs.com/legal/privacy")!)
                            .font(.caption).foregroundStyle(tema.c1)
                        Text("·").foregroundStyle(.rvMut).font(.caption)
                        Link(yerel.p("kullanımKosullari"), destination: URL(string: "https://nickdegs.com/legal/tos")!)
                            .font(.caption).foregroundStyle(tema.c1)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4).padding(.bottom, 8)
                    .padding(16)
                }
            }
            .navigationTitle(yerel.t("gorunumTema"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(yerel.t("bitti")) { dismiss() }.bold().foregroundStyle(tema.c1)
                }
            }
        }
        .tint(tema.c1)
        .preferredColorScheme(tema.renkSemasi)   // ayar sheet'i de canlı açık/koyu/sistem geçer
    }

    // Dil seçimi (otomatik cihaz dili + manuel)
    var dilBolumu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(yerel.t("dil")).font(.headline).foregroundStyle(.rvText)
            Text(yerel.t("dilAlt")).font(.caption).foregroundStyle(.rvMut)
            LazyVGrid(columns: kolon, spacing: 10) {
                dilKart("", yerel.t("dilSistem"))
                ForEach(Yerel.diller, id: \.self) { d in dilKart(d, Yerel.dilAd[d] ?? d) }
            }.padding(.top, 6)
        }
    }
    func dilKart(_ kod: String, _ ad: String) -> some View {
        let secili = yerel.secim == kod
        return Button { withAnimation(.snappy) { yerel.secim = kod } } label: {
            HStack(spacing: 8) {
                Text(ad).font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if secili { Image(systemName: "checkmark.circle.fill").foregroundStyle(tema.c1) }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.rvCard, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(secili ? tema.c1 : Color.rvLine, lineWidth: secili ? 2 : 1))
        }.buttonStyle(.plain)
    }

    // Canlı önizleme kartı
    var onizleme: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(tema.grad)
                Text("RealVirtuality").font(.headline.bold()).foregroundStyle(.rvText)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.yellow)
                    Text("120").font(.subheadline.bold()).foregroundStyle(.rvText)
                }.padding(.horizontal, 10).padding(.vertical, 5)
                 .background(.ultraThinMaterial, in: .capsule)
            }
            Text("Yapay zekânın tüm gücü")
                .font(.title3.bold()).foregroundStyle(tema.grad)
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [tema.c1.opacity(0.22), tema.c2.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.aperture").font(.system(size: 20, weight: .semibold)).foregroundStyle(tema.grad)
                }
                Text("Örnek araç kartı").font(.subheadline.bold()).foregroundStyle(.rvText)
                Spacer()
            }
            Button { dismiss() } label: {
                Text("Hemen Kullan")
                    .font(.subheadline.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(tema.grad, in: .rect(cornerRadius: 13))
            }
        }
        .padding(16)
        .background(Color.rvCard, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.rvLine, lineWidth: 1))
    }

    func paletKart(_ p: Palet) -> some View {
        let secili = tema.paletId == p.id
        return Button { withAnimation(.snappy) { tema.paletId = p.id } } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(p.grad).frame(width: 34, height: 34)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                    if let ik = p.ikon { Image(systemName: ik).font(.system(size: 14, weight: .bold)).foregroundStyle(.white) }
                }
                Text(p.ad).font(.subheadline.bold()).foregroundStyle(.rvText)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if secili { Image(systemName: "checkmark.circle.fill").foregroundStyle(p.c1) }
            }
            .padding(12)
            .background(Color.rvCard, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(secili ? p.c1 : Color.rvLine, lineWidth: secili ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}
