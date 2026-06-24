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
        Array(repeating: GridItem(.flexible(), spacing: 18), count: sutunSayisi)
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
                    VStack(alignment: .leading, spacing: 34) {
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
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ust }
            .sheet(isPresented: $girisAcik) { LoginView().environmentObject(api).environmentObject(tema).environmentObject(yerel) }
            .sheet(isPresented: $krediAcik) { KrediView().environmentObject(api).environmentObject(tema).environmentObject(yerel) }
            .sheet(isPresented: $ayarlarAcik) { AyarlarView().environmentObject(api).environmentObject(tema).environmentObject(yerel) }
        }
        .tint(tema.c1)
    }

    // MARK: arka plan
    var arkaplan: some View {
        ZStack {
            LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            LensFlare(c1: tema.c1, c2: tema.c2).opacity(0.95)
        }
    }

    // MARK: üst bar (taşmaz)
    @ToolbarContentBuilder
    var ust: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { ayarlarAcik = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").foregroundStyle(tema.grad)
                    Text("RV").font(.headline.bold()).foregroundStyle(.rvText)
                }
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
            HStack(spacing: 7) {
                Image(systemName: "sparkles").font(.subheadline).foregroundStyle(tema.grad)
                Text(yerel.t("studyoEyebrow")).font(.subheadline.weight(.semibold)).foregroundStyle(.rvMut)
            }
            Text(yerel.t("heroBaslik1"))
                .font(.system(size: 36, weight: .heavy)).foregroundStyle(.rvText)
                .fixedSize(horizontal: false, vertical: true)
            Text(yerel.t("heroBaslik2"))
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(tema.grad)
                .fixedSize(horizontal: false, vertical: true)
            Text(yerel.t("heroAlt"))
                .font(.body).foregroundStyle(.rvMut)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    // MARK: arama
    var aramaKutusu: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.body).foregroundStyle(.rvMut)
            TextField(yerel.t("aramaIpucu"), text: $arama)
                .foregroundStyle(.rvText).autocorrectionDisabled()
            if !arama.isEmpty {
                Button { arama = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.rvMut) }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    // MARK: kategori bölümü
    func bolum(_ kat: Kategori, _ liste: [Arac]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(LinearGradient(colors: [tema.c1.opacity(0.30), tema.c2.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 30, height: 30)
                    Image(systemName: kat.ikon).font(.system(size: 14, weight: .semibold)).foregroundStyle(tema.grad)
                }
                Text(yerel.t(kat.key)).font(.title2.bold()).foregroundStyle(.rvText)
            }
            grid(liste)
        }
    }

    func grid(_ liste: [Arac]) -> some View {
        LazyVGrid(columns: kolonlar, spacing: 18) {
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
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: "https://nickdegs.com/arac-gorsel/\(arac.id).webp")) { phase in
                if let img = phase.image { img.resizable().scaledToFill() }
                else {
                    ZStack {
                        LinearGradient(colors: [tema.c1.opacity(0.28), tema.c2.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: arac.ikon).font(.system(size: 30, weight: .semibold)).foregroundStyle(tema.grad)
                    }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 138).clipped()
            VStack(alignment: .leading, spacing: 7) {
                Text(yerel.aracMetin(arac.id,"ad")).font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(1)
                Text(yerel.aracMetin(arac.id,"aciklama")).font(.caption).foregroundStyle(.rvMut)
                    .lineLimit(2).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                    Text("\(arac.kredi)").font(.caption.bold()).foregroundStyle(tema.c2)
                    if arac.oneCikan {
                        Spacer(minLength: 0)
                        Text(yerel.t("populer")).font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(tema.c1.opacity(0.18), in: .capsule).foregroundStyle(tema.c1)
                    }
                }.padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.rvCard).clipShape(.rect(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.rvLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 7)
    }
}
