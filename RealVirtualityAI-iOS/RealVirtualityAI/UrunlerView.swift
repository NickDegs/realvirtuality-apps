import SwiftUI
import WebKit

// MARK: - Ürün modeli (urunler.json — bireysel + içerik üretici)
struct RVUrun: Identifiable, Decodable {
    let id: String
    let sekme: String
    let g: String
    let ic: String
    let ad: [String:String]
    let aciklama: [String:String]
    let pr: String
}
enum RVKatalog {
    static let urunler: [RVUrun] = {
        guard let u = Bundle.main.url(forResource: "urunler", withExtension: "json"),
              let d = try? Data(contentsOf: u),
              let a = try? JSONDecoder().decode([RVUrun].self, from: d) else { return [] }
        return a
    }()
    static let kategoriSira = ["bireysel","pro","sosyal"]
}

struct UrunlerView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Environment(\.horizontalSizeClass) var hsc
    @State private var arama = ""
    @State private var secilen: RVUrun? = nil

    private var kolonlar: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 18), count: hsc == .regular ? 3 : 2) }
    private var urunler: [RVUrun] {
        let q = arama.trimmingCharacters(in: .whitespaces).lowercased()
        return RVKatalog.urunler.filter { q.isEmpty || yerel.u($0.ad).lowercased().contains(q) || yerel.u($0.aciklama).lowercased().contains(q) }
    }
    private var kategoriler: [String] {
        let m = Set(urunler.map { $0.g }); return RVKatalog.kategoriSira.filter { m.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                LensFlare().opacity(0.7)
                ScrollView {
                    VStack(alignment: .leading, spacing: 34) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(yerel.p("urunHero1")).font(.largeTitle.bold()).foregroundStyle(.rvText)
                            Text(yerel.p("urunHero2")).font(.largeTitle.bold()).foregroundStyle(tema.grad).shimmer()
                        }.padding(.top, 12)
                        aramaKutusu
                        ForEach(kategoriler, id: \.self) { g in
                            let liste = urunler.filter { $0.g == g }
                            VStack(alignment: .leading, spacing: 18) {
                                Text(yerel.p("kat_" + g)).font(.title2.bold()).foregroundStyle(.rvText)
                                LazyVGrid(columns: kolonlar, spacing: 18) {
                                    ForEach(liste) { u in
                                        BasilabilirKart { secilen = u } content: { RVUrunKart(urun: u) }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 48)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(yerel.p("urunlerTab"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $secilen) { u in NavigationStack { RVUrunDetay(urun: u) } }
        }
        .tint(tema.c1)
    }

    var aramaKutusu: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.rvMut)
            TextField(yerel.p("urunAra"), text: $arama).foregroundStyle(.rvText).autocorrectionDisabled()
            if !arama.isEmpty { Button { arama = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.rvMut) } }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

struct RVUrunKart: View {
    let urun: RVUrun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: "https://nickdegs.com/urun-gorsel/\(urun.id).webp")) { phase in
                if let img = phase.image { img.resizable().scaledToFill() }
                else {
                    ZStack {
                        LinearGradient(colors: [tema.c1.opacity(0.30), tema.c2.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Text(urun.ic).font(.system(size: 40))
                    }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 138).clipped()
            VStack(alignment: .leading, spacing: 7) {
                Text(yerel.u(urun.ad)).font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(1)
                Text(yerel.u(urun.aciklama)).font(.caption).foregroundStyle(.rvMut).lineLimit(2).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                if !urun.pr.isEmpty { Text(urun.pr).font(.caption.bold()).foregroundStyle(tema.c2).padding(.top, 3) }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.rvCard).clipShape(.rect(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.rvLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    }
}

struct RVUrunDetay: View {
    let urun: RVUrun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @State private var webAcik = false
    private var url: URL {
        let yol = urun.sekme == "bireysel" ? "urunler" : "dijital"
        return URL(string: "https://nickdegs.com/\(yol)?grup=\(urun.g)#\(urun.id)")!
    }
    var body: some View {
        ZStack {
            LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            LensFlare().opacity(0.8)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        AsyncImage(url: URL(string: "https://nickdegs.com/urun-gorsel/\(urun.id).webp")) { phase in
                            if let img = phase.image { img.resizable().scaledToFill() }
                            else { ZStack { LinearGradient(colors: [tema.c1.opacity(0.28), tema.c2.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing); Text(urun.ic).font(.system(size: 36)) } }
                        }
                        .frame(width: 80, height: 80).clipShape(.rect(cornerRadius: 20))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(yerel.u(urun.ad)).font(.title2.bold()).foregroundStyle(.rvText).fixedSize(horizontal: false, vertical: true)
                            Text(yerel.p("kat_" + urun.g)).font(.caption).foregroundStyle(.rvMut)
                        }
                        Spacer(minLength: 0)
                    }.padding(.top, 6)
                    if !urun.pr.isEmpty {
                        Text(urun.pr).font(.title3.bold()).foregroundStyle(tema.c2).padding(.horizontal, 16).padding(.vertical, 9).glassEffect(.regular.tint(tema.c2.opacity(0.18)), in: .capsule)
                    }
                    Text(yerel.u(urun.aciklama)).font(.callout).foregroundStyle(.rvText).opacity(0.95).fixedSize(horizontal: false, vertical: true).padding(18).frame(maxWidth: .infinity, alignment: .leading).glassEffect(.regular, in: .rect(cornerRadius: 20))
                    Color.clear.frame(height: 80)
                }.padding(.horizontal, 16).padding(.top, 8)
            }
            VStack { Spacer()
                Button { webAcik = true } label: {
                    HStack(spacing: 8) { Image(systemName: "cart.fill"); Text(yerel.p("urunIncele")) }
                        .font(.headline.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(tema.grad, in: .rect(cornerRadius: 20)).shadow(color: tema.c1.opacity(0.45), radius: 16, y: 7)
                }.padding(.horizontal, 16).padding(.bottom, 10)
            }
        }
        .navigationTitle(yerel.u(urun.ad)).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $webAcik) { RVPanel(url: url, baslik: yerel.u(urun.ad)) }
    }
}

struct RVPanel: View {
    let url: URL; let baslik: String
    @EnvironmentObject var tema: Tema
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            RVWeb(url: url).ignoresSafeArea(edges: .bottom)
                .navigationTitle(baslik).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("✕") { dismiss() }.foregroundStyle(tema.c1) } }
        }.tint(tema.c1)
    }
}
struct RVWeb: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView(); wv.allowsBackForwardNavigationGestures = true; wv.load(URLRequest(url: url)); return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
