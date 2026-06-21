import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Environment(\.horizontalSizeClass) var hsc
    @State private var girisAcik = false
    @State private var krediAcik = false
    @State private var ayarlarAcik = false
    @State private var arama = ""

    // Responsive sütun sayısı — taşmayı tamamen önler (.flexible eşit böler)
    private var sutunSayisi: Int { hsc == .regular ? 3 : 2 }
    private var kolonlar: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: sutunSayisi)
    }

    private var sonuclar: [Arac] {
        let q = arama.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return ARACLAR.filter {
            yerel.aracMetin($0.id,"ad").lowercased().contains(q) ||
            yerel.aracMetin($0.id,"aciklama").lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                arkaplan
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        kahraman
                        aramaKutusu

                        if !arama.isEmpty {
                            grid(sonuclar)
                        } else {
                            ForEach(Kategori.allCases) { kat in
                                let liste = ARACLAR.filter { $0.kategori == kat }
                                if !liste.isEmpty { bolum(kat, liste) }
                            }
                            altBilgi
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ust }
            .sheet(isPresented: $girisAcik) { LoginView() }
            .sheet(isPresented: $krediAcik) { KrediView() }
            .sheet(isPresented: $ayarlarAcik) { AyarlarView() }
        }
        .tint(tema.c1)
    }

    // MARK: arka plan
    var arkaplan: some View {
        ZStack {
            LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            LensFlare().opacity(0.9)
        }
    }

    // MARK: üst bar (taşmaz)
    @ToolbarContentBuilder
    var ust: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .foregroundStyle(tema.grad)
                Text("RealVirtuality").font(.headline.bold()).foregroundStyle(.rvText)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 8) {
                Button { api.girisli ? (krediAcik = true) : (girisAcik = true) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.yellow)
                        Text("\(api.girisli ? api.kredi : api.freeKalan)").font(.subheadline.bold()).foregroundStyle(.rvText)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: .capsule)
                    .overlay(Capsule().stroke(Color.rvLine, lineWidth: 1))
                }
                Menu {
                    Button { ayarlarAcik = true } label: { Label(yerel.t("gorunumTema"), systemImage: "paintpalette.fill") }
                    Button { api.girisli ? (krediAcik = true) : (girisAcik = true) } label: { Label(yerel.t("krediAl"), systemImage: "bolt.fill") }
                    Divider()
                    Button { girisAcik = true } label: { Label(api.girisli ? (api.email ?? yerel.t("hesabim")) : yerel.t("girisYap"), systemImage: "person.crop.circle") }
                } label: {
                    Image(systemName: api.girisli ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(.title3).foregroundStyle(.rvText)
                }
            }
        }
    }

    // MARK: kahraman / hero
    var kahraman: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(yerel.t("heroBaslik1"))
                .font(.largeTitle.bold()).foregroundStyle(.rvText)
            Text(yerel.t("heroBaslik2"))
                .font(.largeTitle.bold())
                .foregroundStyle(tema.grad)
                .shimmer()
            Text(yerel.t("heroAlt"))
                .font(.subheadline).foregroundStyle(.rvMut)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    // MARK: arama
    var aramaKutusu: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.rvMut)
            TextField(yerel.t("aramaIpucu"), text: $arama)
                .foregroundStyle(.rvText).autocorrectionDisabled()
            if !arama.isEmpty {
                Button { arama = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.rvMut) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color.rvCard, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvLine, lineWidth: 1))
    }

    // MARK: kategori bölümü
    func bolum(_ kat: Kategori, _ liste: [Arac]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: kat.ikon).font(.subheadline).foregroundStyle(tema.c2)
                Text(yerel.t(kat.key)).font(.title3.bold()).foregroundStyle(.rvText)
            }
            grid(liste)
        }
    }

    func grid(_ liste: [Arac]) -> some View {
        LazyVGrid(columns: kolonlar, spacing: 12) {
            ForEach(liste) { a in
                NavigationLink { AracDetayView(arac: a) } label: { AracKart(arac: a) }
                    .buttonStyle(.plain)
            }
        }
    }

    var altBilgi: some View {
        VStack(spacing: 4) {
            Text(yerel.t("nickdegsUrunu")).font(.caption.bold()).foregroundStyle(tema.c1)
            Text("© 2026 RealVirtuality AI").font(.caption2).foregroundStyle(.rvMut)
        }
        .frame(maxWidth: .infinity).padding(.top, 10)
    }
}

// MARK: - Araç kartı (eşit boyutlu, taşmaz)
struct AracKart: View {
    let arac: Arac
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [tema.c1.opacity(0.22), tema.c2.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: arac.ikon).font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tema.grad)
            }
            Text(yerel.aracMetin(arac.id,"ad")).font(.subheadline.bold()).foregroundStyle(.rvText)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(yerel.aracMetin(arac.id,"aciklama")).font(.caption2).foregroundStyle(.rvMut)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                Text("\(arac.kredi)").font(.caption2.bold()).foregroundStyle(tema.c2)
                if arac.oneCikan {
                    Spacer(minLength: 0)
                    Text(yerel.t("populer")).font(.system(size: 8, weight: .heavy))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(tema.c1.opacity(0.18), in: .capsule)
                        .foregroundStyle(tema.c1)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(Color.rvCard, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.rvLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}
