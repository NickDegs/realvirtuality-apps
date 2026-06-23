import SwiftUI
import SafariServices

// App-içi tarayıcı — harici paneller Safari'ye ATMADAN app içinde açılır (swipe ile kapanır)
struct IdURL: Identifiable { let id = UUID(); let url: URL }
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController.Configuration(); c.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: c); vc.dismissButtonStyle = .close; return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

struct HubKart: Decodable, Identifiable, Hashable {
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

// Native ekranı olan bölümler (Safari YOK — her şey native SwiftUI)
let NATIVE_BOLUMLER: Set<String> = ["admin","sunucu","iptv","odemeler","uyeler","teslimat",
    "siparis","stok","randevu","ozet","raporlar","musteriler",
    "koruma","ziyaretci","ban","erisim","isletme_ekle","personel",
    "ulke","asn","ipyonet","adminhub","hediye","demo","medya","kpi","abonelik","kontrol",
    "meta","satis","koordinasyon","satinaldiklarim","hizliodeme"]

struct GrupView: View {
    let grup: HubGrup
    let ad: String
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @Environment(\.horizontalSizeClass) var hsc
    @Environment(\.openURL) var openURL
    @State private var sifreAcik = false
    @State private var hedef: HubKart? = nil
    @State private var safari: IdURL? = nil

    private var kolonlar: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 14), count: hsc == .regular ? 3 : 2) }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                LensFlare().opacity(0.7)
                ScrollView {
                    LazyVGrid(columns: kolonlar, spacing: 14) {
                        ForEach(grup.kartlar) { k in
                            BasilabilirKart { ac(k) } content: { KartGor(kart: k) }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(grup.ad)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $hedef) { k in HedefNative(kart: k) }
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
            .sheet(isPresented: $sifreAcik) { SifreDegistirView() }
            .sheet(item: $safari) { SafariView(url: $0.url).ignoresSafeArea() }
        }
        .tint(tema.c1)
    }
    func ac(_ k: HubKart) {
        if NATIVE_BOLUMLER.contains(k.s) { hedef = k }      // native ekran (push)
        else {                                              // harici panel → app-içi tarayıcı (Safari'ye atmaz)
            let h = oturum.host.hasPrefix("http") ? oturum.host : "https://" + oturum.host
            if let u = URL(string: "\(h)/dash/s?t=\(oturum.token)&s=\(k.s)") { safari = IdURL(url: u) }
        }
    }
}

// Native bölüm yönlendirici
struct HedefNative: View {
    let kart: HubKart
    var body: some View {
        switch kart.s {
        case "kpi": OzetNative()
        case "abonelik": AbonelikNative()
        case "sunucu": SunucuNative()
        case "iptv": IPTVNative()
        case "admin","odemeler","uyeler","teslimat": AdminNative()
        case "siparis": IsletmeVeriNative(kind: "orders", baslik: "Siparişler")
        case "stok": IsletmeVeriNative(kind: "menu", baslik: "Menü / Stok")
        case "randevu": IsletmeVeriNative(kind: "appts", baslik: "Randevular")
        case "musteriler": IsletmeVeriNative(kind: "appts", baslik: "Müşteriler")
        case "ozet","raporlar": IsletmeVeriNative(kind: "stats", baslik: "Raporlar")
        case "koruma": GuvenlikNative(tip: "koruma", baslik: "Koruma Durumu")
        case "ziyaretci": GuvenlikNative(tip: "ziyaretci", baslik: "Ziyaretçi Logları")
        case "ban": GuvenlikNative(tip: "ban", baslik: "Engellenen IP")
        case "erisim": GuvenlikNative(tip: "ziyaretci", baslik: "Erişim Logları")
        case "isletme_ekle": IsletmeEkleNative()
        case "personel": PersonelNative()
        case "ulke": UlkeNative()
        case "asn": AsnNative()
        case "ipyonet": IPYonetNative()
        case "adminhub": AdminHubNative()
        case "hediye": HediyeNative()
        case "demo": DemoNative()
        case "medya": MedyaNative()
        case "kontrol": KontrolMerkeziNative()
        case "meta": MetaAnalizNative()
        case "satis": SatisNative()
        case "koordinasyon": KoordinasyonNative()
        case "satinaldiklarim": SatinAldiklarimNative()
        case "hizliodeme": HizliOdemeNative()
        default: Text("Bu bölüm Safari'de açılır").foregroundStyle(.rvMut)
        }
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

