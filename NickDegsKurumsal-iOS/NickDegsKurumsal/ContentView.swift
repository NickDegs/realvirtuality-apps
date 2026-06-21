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
        Array(repeating: GridItem(.flexible(), spacing: 14), count: hsc == .regular ? 3 : 2)
    }
    private var urunler: [Urun] {
        let q = arama.trimmingCharacters(in: .whitespaces).lowercased()
        return Katalog.urunler.filter {
            $0.sekme == sekme.rawValue &&
            (q.isEmpty || yerel.u($0.ad).lowercased().contains(q) || yerel.u($0.aciklama).lowercased().contains(q))
        }
    }
    private var kategoriler: [String] {
        let mevcut = Set(urunler.map { $0.g })
        return Katalog.kategoriSira.filter { mevcut.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Marka gradyanı arka plan
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                // Mercek yanması (lens flare) — yavaş, ultra yumuşak
                LensFlare()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        kahraman
                        aramaKutusu
                        ForEach(Array(kategoriler.enumerated()), id: \.element) { ki, g in
                            let liste = urunler.filter { $0.g == g }
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 8) {
                                    Image(systemName: katIkon(g)).font(.subheadline).foregroundStyle(tema.c2)
                                    Text(yerel.katAd(g)).font(.title3.bold()).foregroundStyle(.rvText)
                                }
                                GlassEffectContainer(spacing: 14) {
                                    LazyVGrid(columns: kolonlar, spacing: 14) {
                                        ForEach(Array(liste.enumerated()), id: \.element.id) { i, u in
                                            BasilabilirKart { secilenUrun = u } content: {
                                                UrunKart(urun: u)
                                            }
                                            .transition(.scale.combined(with: .opacity))
                                            .animation(.smooth(duration: 0.5).delay(Double(min(i,8)) * 0.04), value: belir)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(yerel.sekmeAd(sekme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 7) {
                        Image(systemName: "diamond.fill").foregroundStyle(tema.grad)
                        Text("NickDegs").font(.headline.bold()).foregroundStyle(.rvText)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(yerel.t("hero1")).font(.largeTitle.bold()).foregroundStyle(.rvText)
            Text(yerel.t("hero2")).font(.largeTitle.bold()).foregroundStyle(tema.grad).shimmer()
            Text(yerel.t("heroAlt")).font(.subheadline).foregroundStyle(.rvMut)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
    }

    var aramaKutusu: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.rvMut)
            TextField(yerel.t("ara"), text: $arama).foregroundStyle(.rvText).autocorrectionDisabled()
            if !arama.isEmpty { Button { arama = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.rvMut) } }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

struct UrunKart: View {
    let urun: Urun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(LinearGradient(colors: [tema.c1.opacity(0.25), tema.c2.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                Text(urun.ic).font(.system(size: 24))
            }
            Text(yerel.u(urun.ad)).font(.subheadline.bold()).foregroundStyle(.rvText)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(yerel.u(urun.aciklama)).font(.caption2).foregroundStyle(.rvMut)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !urun.pr.isEmpty {
                Text(urun.pr).font(.caption.bold()).foregroundStyle(tema.c2)
            }
        }
        .padding(15).frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }
}
