import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @State private var secili: Sekme = .kurumsal

    var body: some View {
        TabView(selection: $secili) {
            ForEach(Sekme.allCases) { s in
                SekmeView(sekme: s)
                    .tabItem { Label(yerel.sekmeAd(s), systemImage: s.ikon) }
                    .tag(s)
            }
        }
    }
}

struct SekmeView: View {
    let sekme: Sekme
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Environment(\.horizontalSizeClass) var hsc
    @State private var ayarlarAcik = false
    @State private var arama = ""

    private var kolonlar: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: hsc == .regular ? 3 : 2)
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
                LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                LensFlare().opacity(0.7)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        kahraman
                        aramaKutusu
                        ForEach(kategoriler, id: \.self) { g in
                            let liste = urunler.filter { $0.g == g }
                            VStack(alignment: .leading, spacing: 12) {
                                Text(yerel.katAd(g)).font(.title3.bold()).foregroundStyle(.rvText)
                                LazyVGrid(columns: kolonlar, spacing: 12) {
                                    ForEach(liste) { u in
                                        NavigationLink { UrunDetayView(urun: u) } label: { UrunKart(urun: u) }
                                            .buttonStyle(.plain)
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
                    Button { ayarlarAcik = true } label: { Image(systemName: "paintpalette").foregroundStyle(.rvText) }
                }
            }
            .sheet(isPresented: $ayarlarAcik) { AyarlarView() }
        }
        .tint(tema.c1)
    }

    var kahraman: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(yerel.t("hero1")).font(.title.bold()).foregroundStyle(.rvText)
            Text(yerel.t("hero2")).font(.title.bold()).foregroundStyle(tema.grad).shimmer()
            Text(yerel.t("heroAlt")).font(.subheadline).foregroundStyle(.rvMut)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
    }

    var aramaKutusu: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.rvMut)
            TextField(yerel.t("ara"), text: $arama).foregroundStyle(.rvText).autocorrectionDisabled()
            if !arama.isEmpty { Button { arama = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.rvMut) } }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color.rvCard, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvLine, lineWidth: 1))
    }
}

struct UrunKart: View {
    let urun: Urun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(urun.ic).font(.system(size: 30))
            Text(yerel.u(urun.ad)).font(.subheadline.bold()).foregroundStyle(.rvText)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(yerel.u(urun.aciklama)).font(.caption2).foregroundStyle(.rvMut)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !urun.pr.isEmpty { Text(urun.pr).font(.caption.bold()).foregroundStyle(tema.c2) }
        }
        .padding(13).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color.rvCard, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.rvLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}
