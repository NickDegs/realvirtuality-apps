import SwiftUI
import WebKit

struct HubKart: Decodable, Identifiable {
    let ic: String; let baslik: String; let alt: String; let s: String
    var id: String { s + baslik }
}
struct HubGrup: Decodable, Identifiable {
    let ad: String; let ikon: String; let kartlar: [HubKart]
    var id: String { ad }
}

struct MainView: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var gruplar: [HubGrup] = []
    @State private var ad = ""
    @State private var yukleniyor = true
    @State private var hata = false

    var body: some View {
        Group {
            if yukleniyor {
                ZStack { AnimatedArka(c1: tema.c1, c2: tema.c2); ProgressView().tint(tema.c1).scaleEffect(1.3) }
            } else if hata || gruplar.isEmpty {
                ZStack {
                    AnimatedArka(c1: tema.c1, c2: tema.c2)
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark").font(.system(size: 44)).foregroundStyle(tema.c1)
                        Text("Panel yüklenemedi").foregroundStyle(.rvText)
                        Button("Tekrar dene") { Task { await yukle() } }.foregroundStyle(tema.c1).bold()
                        Button("Çıkış") { oturum.cikis() }.foregroundStyle(.rvMut)
                    }
                }
            } else {
                TabView {
                    ForEach(gruplar) { g in
                        GrupView(grup: g, ad: ad)
                            .tabItem { Label(g.ad, systemImage: g.ikon) }
                    }
                }
                .tint(tema.c1)
            }
        }
        .task { await yukle() }
    }

    func yukle() async {
        yukleniyor = true; hata = false
        let h = oturum.host.hasPrefix("http") ? oturum.host : "https://" + oturum.host
        guard let url = URL(string: "\(h)/api/panel/hub?t=\(oturum.token)") else { hata = true; yukleniyor = false; return }
        do {
            let (d, _) = try await URLSession.shared.data(from: url)
            struct Yanit: Decodable { let ok: Bool; let ad: String?; let gruplar: [HubGrup]? }
            let y = try JSONDecoder().decode(Yanit.self, from: d)
            if y.ok, let g = y.gruplar { gruplar = g; ad = y.ad ?? ""; hata = false }
            else { oturum.cikis() }   // token geçersiz → giriş ekranına
        } catch { hata = true }
        yukleniyor = false
    }
}

struct GrupView: View {
    let grup: HubGrup
    let ad: String
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @Environment(\.horizontalSizeClass) var hsc
    @State private var acilan: HubKart? = nil
    @State private var sifreAcik = false

    private var kolonlar: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 14), count: hsc == .regular ? 3 : 2) }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                LensFlare().opacity(0.7)
                ScrollView {
                    LazyVGrid(columns: kolonlar, spacing: 14) {
                        ForEach(grup.kartlar) { k in
                            BasilabilirKart { acilan = k } content: { KartGor(kart: k) }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(grup.ad)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 7) { Image(systemName: "diamond.fill").foregroundStyle(tema.grad); Text("NickDegs").font(.headline.bold()).foregroundStyle(.rvText) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Text(ad)
                        Button { sifreAcik = true } label: { Label("Şifre Değiştir", systemImage: "lock.rotation") }
                        Button("Çıkış Yap", role: .destructive) { oturum.cikis() }
                    } label: { Image(systemName: "person.crop.circle").font(.title3).foregroundStyle(.rvText) }
                }
            }
            .sheet(item: $acilan) { k in
                let h = oturum.host.hasPrefix("http") ? oturum.host : "https://" + oturum.host
                PanelWeb2(url: URL(string: "\(h)/dash/s?t=\(oturum.token)&s=\(k.s)")!, baslik: k.baslik)
            }
            .sheet(isPresented: $sifreAcik) { SifreDegistirView() }
        }
        .tint(tema.c1)
    }
}

struct KartGor: View {
    let kart: HubKart
    @EnvironmentObject var tema: Tema
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [tema.c1.opacity(0.28), tema.c2.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: kart.ic).font(.system(size: 23, weight: .semibold)).foregroundStyle(tema.grad)
            }
            Text(kart.baslik).font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(kart.alt).font(.caption2).foregroundStyle(.rvMut).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(15).frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }
}

// Sheet içi WebView (kapatma butonlu)
struct PanelWeb2: View {
    let url: URL; let baslik: String
    @EnvironmentObject var tema: Tema
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            BasitWeb(url: url).ignoresSafeArea(edges: .bottom)
                .navigationTitle(baslik).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(tema.c1) } }
        }.tint(tema.c1)
    }
}

struct BasitWeb: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView(); wv.allowsBackForwardNavigationGestures = true; wv.load(URLRequest(url: url)); return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
