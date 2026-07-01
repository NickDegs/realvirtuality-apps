import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @State private var secili: Sekme = .isletme

    var body: some View {
        TabView(selection: $secili) {
            ForEach(Sekme.allCases) { s in
                SekmeView(sekme: s)
                    .tabItem { Label(yerel.sekmeAd(s), systemImage: s.ikon) }
                    .tag(s)
            }
        }
        .animation(.smooth(duration: 0.4), value: secili)
    }
}

struct SekmeView: View {
    let sekme: Sekme
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Environment(\.horizontalSizeClass) var hsc
    @State private var ayarlarAcik = false
    @State private var secilenUrun: Urun? = nil
    @State private var arama = ""
    @State private var belir = false

    private var kolonlar: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: hsc == .regular ? 3 : 2)
    }
    private var urunler: [Urun] {
        let q = arama.trimmingCharacters(in: .whitespaces).lowercased()
        return Katalog.urunler.filter {
            $0.sekme == sekme.rawValue &&
            (q.isEmpty || yerel.u($0.ad).lowercased().contains(q) || yerel.u($0.aciklama).lowercased().contains(q))
        }
    }
    // Spotlight: bölümün ilk ürünü (öne çıkan)
    private var oneCikanUrun: Urun? { urunler.first }
    private var kategoriler: [String] {
        let mevcut = Set(urunler.map { $0.g })
        return Katalog.kategoriSira.filter { mevcut.contains($0) }
    }

    var body: some View {
        if sekme == .isletmeler {
            IsletmelerView()
        } else if sekme == .hesabim {
            HesabimView()
        } else {
            katalogEkrani
        }
    }

    var katalogEkrani: some View {
        NavigationStack {
            ZStack {
                // Marka gradyanı arka plan
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                // Mercek yanması (lens flare) — yavaş, ultra yumuşak, tema renginde
                LensFlare(c1: tema.c1, c2: tema.c2)
                ScrollView {
                    VStack(alignment: .leading, spacing: 34) {
                        kahraman
                        aramaKutusu
                        if arama.isEmpty, let one = oneCikanUrun {
                            BasilabilirKart { secilenUrun = one } content: { SpotlightKart(urun: one) }
                        }
                        ForEach(Array(kategoriler.enumerated()), id: \.element) { ki, g in
                            let liste = urunler.filter { $0.g == g }
                            VStack(alignment: .leading, spacing: 18) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(LinearGradient(colors: [tema.c1.opacity(0.30), tema.c2.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 30, height: 30)
                                        Image(systemName: katIkon(g)).font(.system(size: 14, weight: .semibold)).foregroundStyle(tema.grad)
                                    }
                                    Text(yerel.katAd(g)).font(.title2.bold()).foregroundStyle(.rvText)
                                }
                                LazyVGrid(columns: kolonlar, spacing: 16) {
                                    ForEach(liste) { u in
                                        BasilabilirKart { secilenUrun = u } content: {
                                            UrunKart(urun: u)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(yerel.sekmeAd(sekme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { ayarlarAcik = true } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "diamond.fill").foregroundStyle(tema.grad)
                            Text("NickDegs").font(.headline.bold()).foregroundStyle(.rvText)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { ayarlarAcik = true } label: {
                        Image(systemName: "paintpalette").font(.title3).padding(7)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }.foregroundStyle(.rvText)
                }
            }
            .sheet(isPresented: $ayarlarAcik) { AyarlarView() }
            .sheet(item: $secilenUrun) { u in
                NavigationStack { UrunDetayView(urun: u) }
            }
        }
        .tint(tema.c1)
        .onAppear { belir = true }
    }

    func katIkon(_ g: String) -> String {
        switch g {
        case "bireysel": return "person.fill"
        case "pro": return "briefcase.fill"
        case "sosyal": return "bubble.left.and.bubble.right.fill"
        case "isletme": return "storefront.fill"
        case "akilli": return "cpu.fill"
        case "kurumsal": return "building.2.fill"
        case "guvenlik": return "lock.shield.fill"
        default: return "square.grid.2x2.fill"
        }
    }

    var kahraman: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sekme == .guvenlik ? yerel.t("guvenlikEyebrow") : yerel.t("magazaEyebrow"))
                .font(.subheadline.weight(.semibold)).foregroundStyle(.rvMut)
            Text(yerel.t("hero1")).font(.system(size: 36, weight: .heavy)).foregroundStyle(.rvText)
                .fixedSize(horizontal: false, vertical: true)
            Text(yerel.t("hero2")).font(.system(size: 36, weight: .heavy)).foregroundStyle(tema.grad)
                .fixedSize(horizontal: false, vertical: true)
            Text(yerel.t("heroAlt")).font(.body).foregroundStyle(.rvMut)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
    }

    var aramaKutusu: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.body).foregroundStyle(.rvMut)
            TextField(yerel.t("ara"), text: $arama).foregroundStyle(.rvText).autocorrectionDisabled()
            if !arama.isEmpty { Button { arama = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.rvMut) } }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

// MARK: - Spotlight (öne çıkan) — geniş, ferah feature kartı
struct SpotlightKart: View {
    let urun: Urun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(urun.ic).font(.system(size: 64)).opacity(0.9)
                .padding(22)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").font(.system(size: 11, weight: .bold))
                    Text(yerel.t("oneCikan")).font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.14), in: .capsule).foregroundStyle(.white)

                Text(yerel.u(urun.ad)).font(.system(size: 25, weight: .heavy))
                    .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                Text(yerel.u(urun.aciklama)).font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78)).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(yerel.t("spotCta"))
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold)).foregroundStyle(Color.rvBg)
                .padding(.horizontal, 20).padding(.vertical, 13)
                .background(tema.grad, in: .rect(cornerRadius: 15))
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(
            LinearGradient(colors: [tema.c1.opacity(0.24), tema.c2.opacity(0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 28)
        )
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(tema.c1.opacity(0.30), lineWidth: 1))
        .shadow(color: tema.c1.opacity(0.22), radius: 24, y: 12)
    }
}

struct UrunKart: View {
    let urun: Urun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: "https://nickdegs.com/urun-gorsel/\(urun.id).webp")) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(colors: [tema.c1.opacity(0.30), tema.c2.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Text(urun.ic).font(.system(size: 40))
                    }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 132).clipped()
            VStack(alignment: .leading, spacing: 7) {
                Text(yerel.u(urun.ad)).font(.system(size: 16, weight: .bold)).foregroundStyle(.rvText)
                    .lineLimit(1)
                Text(yerel.u(urun.aciklama)).font(.caption).foregroundStyle(.rvMut)
                    .lineLimit(2).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                Text(yerel.t("planDahil")).font(.caption2.weight(.semibold)).foregroundStyle(tema.c2)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(tema.c2.opacity(0.14), in: .capsule).padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.rvCard)
        .clipShape(.rect(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.rvLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.20), radius: 14, y: 7)
    }
}
