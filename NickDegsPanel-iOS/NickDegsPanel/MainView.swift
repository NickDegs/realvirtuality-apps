import SwiftUI

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
let NATIVE_BOLUMLER: Set<String> = [
    // Süper admin
    "admin","sunucu","iptv","odemeler","uyeler","teslimat","isletme_ekle",
    "ziyaretci","ban","koruma","ulke","asn","ipyonet","adminhub","hediye","demo",
    "medya","kpi","abonelik","kontrol","meta","satis","koordinasyon","satinaldiklarim","hizliodeme",
    "kisisel","is","seslendir","gorsel","hukuk","aistudio","traccar","chat","komuta",
    // İşletme sahibi
    "siparis","stok","randevu","ozet","raporlar","musteriler","erisim","personel",
    "qr","gorevlerim","sitem","ayarlar","kampanya","kanit","destek","baglan",
    // Hukuk sektörü
    "davalar","belgeler","sureler",
    // Master admin — müşteri işletmeleri
    "isletmeler",
]

struct GrupView: View {
    let grup: HubGrup
    let ad: String
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @Environment(\.horizontalSizeClass) var hsc
    @State private var sifreAcik = false
    @State private var hedef: HubKart? = nil

    private var kolonlar: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 16), count: hsc == .regular ? 3 : 2) }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                LensFlare(c1: tema.c1, c2: tema.c2).opacity(0.75)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !ad.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.wave.fill").font(.subheadline).foregroundStyle(tema.c2)
                                Text(ad).font(.subheadline.weight(.semibold)).foregroundStyle(.rvMut)
                            }
                            .padding(.top, 2)
                        }
                        LazyVGrid(columns: kolonlar, spacing: 16) {
                            ForEach(grup.kartlar) { k in
                                BasilabilirKart { ac(k) } content: { KartGor(kart: k) }
                            }
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 40)
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
        }
        .tint(tema.c1)
    }
    func ac(_ k: HubKart) {
        hedef = k   // tüm kartlar native — bilinmeyenler HedefNative.default → "Yakında"
    }
}

// Native bölüm yönlendirici
struct HedefNative: View {
    let kart: HubKart
    var body: some View {
        switch kart.s {
        // ── Süper Admin ──
        case "kpi": OzetNative()
        case "abonelik": AbonelikNative()
        case "sunucu": SunucuNative()
        case "iptv": IPTVNative()
        case "admin","odemeler","uyeler","teslimat": AdminNative()
        case "koruma": GuvenlikNative(tip: "koruma", baslik: "Koruma Durumu")
        case "ziyaretci": GuvenlikNative(tip: "ziyaretci", baslik: "Ziyaretçi Logları")
        case "ban": GuvenlikNative(tip: "ban", baslik: "Engellenen IP")
        case "isletme_ekle": IsletmeEkleNative()
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
        case "kisisel": KisiselNative()
        case "is": IsNative()
        case "seslendir": SeslendirNative()
        case "gorsel": GorselNative()
        case "hukuk": HukukNative()
        case "aistudio": AistudioNative()
        case "traccar": TraccarNative()
        case "chat": ChatNative()
        case "komuta": KomutaNative()
        // ── İşletme Sahibi / Çalışan ──
        case "siparis": IsletmeVeriNative(kind: "orders", baslik: "Siparişler")
        case "stok": IsletmeVeriNative(kind: "menu", baslik: "Menü / Stok")
        case "randevu": IsletmeVeriNative(kind: "appts", baslik: "Randevular")
        case "musteriler": IsletmeVeriNative(kind: "appts", baslik: "Müşteriler")
        case "ozet","raporlar": IsletmeVeriNative(kind: "stats", baslik: "Raporlar")
        case "erisim": GuvenlikNative(tip: "ziyaretci", baslik: "Erişim Logları")
        case "personel": PersonelNative()
        case "qr": QRNative()
        case "gorevlerim": GorevlerimNative()
        case "sitem": SitemNative()
        case "ayarlar": AyarlarNative()
        case "kampanya": KampanyaNative()
        case "kanit": KanitNative()
        case "destek": DestekNative()
        case "baglan": BaglanNative()
        case "davalar": BizHukukNative(kind: "davalar")
        case "sureler": BizHukukNative(kind: "sureler")
        case "belgeler": BizHukukNative(kind: "belgeler")
        case "isletmeler": IsletmelerNative()
        default: Text("Yakında…").foregroundStyle(.rvMut).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct KartGor: View {
    let kart: HubKart
    @EnvironmentObject var tema: Tema
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [tema.c1.opacity(0.30), tema.c2.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                Image(systemName: kart.ic).font(.system(size: 25, weight: .semibold)).foregroundStyle(tema.grad)
            }
            Text(kart.baslik).font(.system(size: 17, weight: .bold)).foregroundStyle(.rvText)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            Text(kart.alt).font(.caption).foregroundStyle(.rvMut).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                    .shadow(color: .green.opacity(0.8), radius: 4)
                Text("Aktif").font(.system(size: 12, weight: .semibold)).foregroundStyle(.green)
            }
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }
}

