import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: API
    @State private var girisAcik = false
    @State private var secilen: Arac? = nil

    let kolonlar = [GridItem(.adaptive(minimum: 158), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                // Arka plan — marka gradyanı (Liquid Glass altında parlasın)
                LinearGradient(colors: [.rvBg, Color(red:0.07,green:0.05,blue:0.18), .rvBg],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                Circle().fill(Color.rvViolet.opacity(0.25)).frame(width: 360).blur(radius: 140)
                    .offset(x: 120, y: -260)
                Circle().fill(Color.rvCyan.opacity(0.18)).frame(width: 320).blur(radius: 150)
                    .offset(x: -140, y: 320)

                ScrollView {
                    VStack(spacing: 22) {
                        baslik
                        kahraman
                        GlassEffectContainer(spacing: 14) {
                            LazyVGrid(columns: kolonlar, spacing: 14) {
                                ForEach(ARACLAR) { a in
                                    AracKart(arac: a).onTapGesture {
                                        if api.girisli || api.freeKalan > 0 { secilen = a } else { girisAcik = true }
                                    }
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
            // Kredi rozeti — Liquid Glass
            Text(api.girisli ? "⚡ \(api.kredi)" : "⚡ \(api.freeKalan) ücretsiz")
                .font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 8)
                .glassEffect(.regular.tint(.rvCyan.opacity(0.25)), in: .capsule)
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
