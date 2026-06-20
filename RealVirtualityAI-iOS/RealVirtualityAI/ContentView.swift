import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: API
    @State private var girisAcik = false
    @State private var krediAcik = false
    @State private var secilen: Arac? = nil

    let kolonlar = [GridItem(.adaptive(minimum: 158), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                // Arka plan — marka gradyanı (Liquid Glass altında parlasın)
                LinearGradient(colors: [.rvBg, Color(red:0.07,green:0.05,blue:0.18), .rvBg],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                // Mercek yanma (lens flare) — yavaş, ultra yumuşak gezen ışık
                LensFlare()

                ScrollView {
                    VStack(spacing: 22) {
                        baslik
                        kahraman
                        GlassEffectContainer(spacing: 14) {
                            LazyVGrid(columns: kolonlar, spacing: 14) {
                                ForEach(Array(ARACLAR.enumerated()), id: \.element.id) { i, a in
                                    BasilabilirKart {
                                        if api.girisli || api.freeKalan > 0 { secilen = a } else { girisAcik = true }
                                    } content: {
                                        AracKart(arac: a)
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.smooth(duration: 0.5).delay(Double(i) * 0.05), value: api.girisli)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $girisAcik) { LoginView() }
            .sheet(isPresented: $krediAcik) { KrediView() }
            .sheet(item: $secilen) { a in ToolView(arac: a) }
        }
    }

    var baslik: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(.linearGradient(colors: [.rvViolet, .rvCyan], startPoint: .top, endPoint: .bottom))
                Text("RealVirtuality AI").font(.headline.bold())
            }
            Spacer()
            // Kredi rozeti — basınca Kredi Al (IAP); giriş yoksa önce giriş
            Button { if api.girisli { krediAcik = true } else { girisAcik = true } } label: {
                Text(api.girisli ? "⚡ \(api.kredi)" : "⚡ \(api.freeKalan) ücretsiz")
                    .font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 8)
                    .glassEffect(.regular.tint(.rvCyan.opacity(0.25)), in: .capsule)
            }.foregroundStyle(.white)
            // Hesap
            Button { girisAcik = true } label: {
                Image(systemName: api.girisli ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.title3).padding(8).glassEffect(.regular.interactive(), in: .circle)
            }.foregroundStyle(.white)
        }
        .padding(.horizontal, 18).padding(.top, 14)
    }

    var kahraman: some View {
        VStack(spacing: 8) {
            Text("Yapay zekânın tüm gücü").font(.title.bold())
            Text("tek yerde").font(.title.bold())
                .foregroundStyle(.linearGradient(colors: [.rvViolet, .rvCyan], startPoint: .leading, endPoint: .trailing))
                .shimmer()
            Text("Görsel, yazı, çeviri, kod ve daha fazlası — saniyeler içinde.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 36).padding(.top, 2)
        }.padding(.top, 6)
    }
}

struct AracKart: View {
    let arac: Arac
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: arac.ikon).font(.system(size: 26))
                .foregroundStyle(.linearGradient(colors: [.rvViolet, .rvCyan], startPoint: .top, endPoint: .bottom))
            Text(arac.ad).font(.headline).foregroundStyle(.white)
            Text(arac.aciklama).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Text("⚡ \(arac.kredi)").font(.caption2.bold()).foregroundStyle(.rvCyan).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }
}
