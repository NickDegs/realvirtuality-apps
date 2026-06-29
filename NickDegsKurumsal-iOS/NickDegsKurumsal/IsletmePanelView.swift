import SwiftUI

// MARK: - Native İşletme Paneli — webteki resto-sistem panelinin native karşılığı
// Sahip kendi kullanıcı adı/şifresiyle (Hesabım'dan gelir) canlı siparişleri yönetir.
// Backend: resto-sistem /api/login,/verifydev,/stats,/orders,/menu (multi-tenant, ?d=<tenant>).

struct PanelSiparis: Identifiable {
    let id: Int, masa: String, tip: String, toplam: Int, durum: Int, not: String, urunSayisi: Int
    init(_ d: [String: Any]) {
        id = d["id"] as? Int ?? 0
        masa = d["table_no"] as? String ?? "-"
        tip = d["otype"] as? String ?? ""
        toplam = d["total"] as? Int ?? 0
        durum = d["status"] as? Int ?? 0
        not = d["note"] as? String ?? ""
        urunSayisi = (d["items"] as? [Any])?.count ?? 0
    }
}

struct PanelUrun: Identifiable {
    let id: Int, ad: String, kategori: String, fiyat: Int, aktif: Bool
    init(_ d: [String: Any]) {
        id = d["id"] as? Int ?? 0
        ad = d["name"] as? String ?? "-"
        kategori = d["category"] as? String ?? ""
        fiyat = d["price"] as? Int ?? 0
        aktif = (d["available"] as? Int ?? 1) == 1
    }
}

@MainActor final class PanelAPI: ObservableObject {
    let taban: String
    let tenant: String
    private let session: URLSession

    @Published var girisli = false
    @Published var otpGerek = false
    @Published var otpHint = ""
    @Published var hata = ""
    @Published var yukleniyor = false

    @Published var gelir = 0
    @Published var adet = 0
    @Published var aktif = 0
    @Published var siparisler: [PanelSiparis] = []
    @Published var menu: [PanelUrun] = []

    init(panelUrl: String, tenant: String) {
        var b = panelUrl
        if let q = b.firstIndex(of: "?") { b = String(b[..<q]) }
        if !b.hasSuffix("/") { b += "/" }
        taban = b
        self.tenant = tenant
        let c = URLSessionConfiguration.default
        c.httpCookieStorage = HTTPCookieStorage.shared
        c.httpShouldSetCookies = true
        c.httpCookieAcceptPolicy = .always
        session = URLSession(configuration: c)
    }

    private var cihaz: String {
        let k = "panel_dev_\(tenant)"
        if let v = UserDefaults.standard.string(forKey: k) { return v }
        let v = UUID().uuidString
        UserDefaults.standard.set(v, forKey: k); return v
    }

    private func url(_ ep: String) -> URL {
        URL(string: taban + "api/" + ep + (ep.contains("?") ? "&" : "?") + "d=" + tenant)!
    }

    @discardableResult
    private func post(_ ep: String, _ body: [String: Any]) async -> [String: Any] {
        var r = URLRequest(url: url(ep)); r.httpMethod = "POST"; r.timeoutInterval = 30
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (d, _) = try? await session.data(for: r),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return j
    }

    private func get(_ ep: String) async -> Any? {
        guard let (d, _) = try? await session.data(from: url(ep)) else { return nil }
        return try? JSONSerialization.jsonObject(with: d)
    }

    func giris(_ u: String, _ p: String) async {
        hata = ""; yukleniyor = true; defer { yukleniyor = false }
        let j = await post("login", ["username": u, "password": p, "device": cihaz, "remember": true])
        if j["ok"] as? Bool == true { girisli = true; await yenile() }
        else if j["needotp"] as? Bool == true { otpGerek = true; otpHint = j["hint"] as? String ?? "" }
        else { hata = j["err"] as? String ?? "Giriş başarısız" }
    }

    func otpDogrula(_ kod: String) async {
        hata = ""; yukleniyor = true; defer { yukleniyor = false }
        let j = await post("verifydev", ["code": kod])
        if j["ok"] as? Bool == true { girisli = true; otpGerek = false; await yenile() }
        else { hata = j["err"] as? String ?? "Kod hatalı" }
    }

    func yenile() async {
        if let s = await get("stats") as? [String: Any] {
            gelir = s["revenue"] as? Int ?? 0
            adet = s["count"] as? Int ?? 0
            aktif = s["active"] as? Int ?? 0
        }
        if let arr = await get("orders") as? [[String: Any]] {
            siparisler = arr.map(PanelSiparis.init)
        }
        if let arr = await get("menu") as? [[String: Any]] {
            menu = arr.map(PanelUrun.init)
        }
    }

    func ilerlet(_ s: PanelSiparis) async {
        if await post("order/\(s.id)/advance", [:])["ok"] as? Bool == true { await yenile() }
    }
    func degistir(_ u: PanelUrun) async {
        if await post("menu/\(u.id)/toggle", [:])["ok"] as? Bool == true { await yenile() }
    }
}

struct IsletmePanelView: View {
    @EnvironmentObject var tema: Tema
    @StateObject private var api: PanelAPI
    let onKadi: String
    let onSifre: String

    @State private var u = ""
    @State private var p = ""
    @State private var kod = ""
    @State private var sekme = 0
    @State private var denendi = false

    static let durumAd = ["🆕 Yeni", "👨‍🍳 Hazırlanıyor", "✅ Hazır", "📦 Teslim edildi"]
    static let durumRenk: [Color] = [.blue, .orange, .green, .gray]

    init(panelUrl: String, tenant: String, kadi: String, sifre: String) {
        _api = StateObject(wrappedValue: PanelAPI(panelUrl: panelUrl, tenant: tenant))
        onKadi = kadi; onSifre = sifre
    }

    var body: some View {
        Group {
            if api.girisli { panel }
            else if api.otpGerek { otpEkran }
            else { girisEkran }
        }
        .navigationTitle("İşletme Paneli")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Hesap bilgileri varsa otomatik giriş dene (tek seferlik)
            if !denendi, !onKadi.isEmpty, !onSifre.isEmpty {
                denendi = true; u = onKadi; p = onSifre
                await api.giris(onKadi, onSifre)
            }
        }
    }

    // MARK: Giriş
    var girisEkran: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "storefront.fill").font(.system(size: 44)).foregroundStyle(tema.grad).padding(.top, 24)
                Text("İşletme Girişi").font(.title2.bold()).foregroundStyle(.rvText)
                TextField("Kullanıcı adı", text: $u).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding().background(Color.rvCard, in: .rect(cornerRadius: 14))
                SecureField("Şifre", text: $p)
                    .padding().background(Color.rvCard, in: .rect(cornerRadius: 14))
                if !api.hata.isEmpty { Text(api.hata).font(.caption).foregroundStyle(.orange) }
                Button { Task { await api.giris(u, p) } } label: {
                    HStack { if api.yukleniyor { ProgressView().tint(.white) }; Text("Giriş Yap").bold() }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(tema.grad, in: .rect(cornerRadius: 14))
                }.disabled(api.yukleniyor || u.isEmpty || p.isEmpty)
            }.padding()
        }
    }

    var otpEkran: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill").font(.system(size: 44)).foregroundStyle(tema.grad).padding(.top, 24)
                Text("Yeni Cihaz Doğrulaması").font(.title3.bold()).foregroundStyle(.rvText)
                Text("Telefonuna (***\(api.otpHint)) gelen 6 haneli kodu gir.").font(.caption).foregroundStyle(.rvMut).multilineTextAlignment(.center)
                TextField("SMS kodu", text: $kod).keyboardType(.numberPad)
                    .padding().background(Color.rvCard, in: .rect(cornerRadius: 14))
                if !api.hata.isEmpty { Text(api.hata).font(.caption).foregroundStyle(.orange) }
                Button { Task { await api.otpDogrula(kod) } } label: {
                    Text("Doğrula").bold().foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(tema.grad, in: .rect(cornerRadius: 14))
                }.disabled(api.yukleniyor || kod.count < 4)
            }.padding()
        }
    }

    // MARK: Panel
    var panel: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sekme) {
                Text("Özet").tag(0); Text("Siparişler").tag(1); Text("Menü").tag(2)
            }.pickerStyle(.segmented).padding()
            ScrollView {
                switch sekme {
                case 0: ozet
                case 1: siparisListe
                default: menuListe
                }
            }
            .refreshable { await api.yenile() }
        }
    }

    var ozet: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                kpi("Bugün Ciro", "₺\(api.gelir)", "turkishlirasign.circle.fill", .green)
                kpi("Bugün Sipariş", "\(api.adet)", "bag.fill", .blue)
            }
            kpi("Aktif Sipariş", "\(api.aktif)", "flame.fill", .orange)
        }.padding()
    }

    func kpi(_ t: String, _ v: String, _ ik: String, _ renk: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: ik).foregroundStyle(renk).font(.title2)
            Text(v).font(.title.bold()).foregroundStyle(.rvText)
            Text(t).font(.caption).foregroundStyle(.rvMut)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color.rvCard, in: .rect(cornerRadius: 16))
    }

    var siparisListe: some View {
        LazyVStack(spacing: 10) {
            if api.siparisler.isEmpty {
                Text("Henüz sipariş yok").foregroundStyle(.rvMut).padding(.top, 40)
            }
            ForEach(api.siparisler) { s in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("#\(s.id)").font(.headline).foregroundStyle(.rvText)
                        if !s.masa.isEmpty && s.masa != "-" {
                            Text("Masa \(s.masa)").font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.rvLine, in: .capsule).foregroundStyle(.rvMut)
                        }
                        Spacer()
                        Text("₺\(s.toplam)").font(.headline).foregroundStyle(tema.c1)
                    }
                    HStack {
                        Text(Self.durumAd[min(3, max(0, s.durum))]).font(.caption.bold())
                            .foregroundStyle(Self.durumRenk[min(3, max(0, s.durum))])
                        Spacer()
                        Text("\(s.urunSayisi) ürün").font(.caption2).foregroundStyle(.rvMut)
                    }
                    if !s.not.isEmpty {
                        Text("📝 \(s.not)").font(.caption2).foregroundStyle(.rvMut)
                    }
                    if s.durum < 3 {
                        Button { Task { await api.ilerlet(s) } } label: {
                            Text("Sonraki aşamaya geçir →").font(.caption.bold()).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(tema.grad, in: .rect(cornerRadius: 10))
                        }
                    }
                }
                .padding(12).background(Color.rvCard, in: .rect(cornerRadius: 14))
            }
        }.padding()
    }

    var menuListe: some View {
        LazyVStack(spacing: 8) {
            if api.menu.isEmpty {
                Text("Menüde ürün yok").foregroundStyle(.rvMut).padding(.top, 40)
            }
            ForEach(api.menu) { m in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.ad).font(.subheadline.bold()).foregroundStyle(.rvText)
                        Text("\(m.kategori) · ₺\(m.fiyat)").font(.caption2).foregroundStyle(.rvMut)
                    }
                    Spacer()
                    Button { Task { await api.degistir(m) } } label: {
                        Text(m.aktif ? "Satışta" : "Tükendi").font(.caption.bold())
                            .foregroundStyle(m.aktif ? .green : .orange)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background((m.aktif ? Color.green : Color.orange).opacity(0.15), in: .capsule)
                    }
                }
                .padding(12).background(Color.rvCard, in: .rect(cornerRadius: 14))
            }
        }.padding()
    }
}
