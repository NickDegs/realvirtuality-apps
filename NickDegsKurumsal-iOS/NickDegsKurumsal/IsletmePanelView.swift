import SwiftUI

// MARK: - Native İşletme Paneli (TÜM SEKTÖRLER) — webteki sektör panellerinin native karşılığı
// Aile: restoran(sipariş/menü/masa) · randevu+öğretmen(randevu/hizmet/müşteri) · hukuk(dava/süre/duruşma/müvekkil/belge)
// Ortak: auth (login+OTP device-lock), personel, ayar. Backend: ?d=<did>, session cookie.

enum PanelAile: String {
    case restoran, randevu, hukuk, ogretmen, bilinmiyor
    static func coz(_ aile: String, base: String) -> PanelAile {
        if let a = PanelAile(rawValue: aile), a != .bilinmiyor { return a }
        let b = base.lowercased()
        if b.contains("restoran") { return .restoran }
        if b.contains("randevu") { return .randevu }
        if b.contains("hukuk") { return .hukuk }
        if b.contains("ogretmen") { return .ogretmen }
        return .bilinmiyor
    }
}

@MainActor final class PanelAPI: ObservableObject {
    let taban: String      // apiBase, sonu /
    let did: String
    let aile: PanelAile
    let sektor: String
    private let session: URLSession

    @Published var girisli = false
    @Published var otpGerek = false
    @Published var otpHint = ""
    @Published var hata = ""
    @Published var yukleniyor = false
    @Published var rol = ""

    init(apiBase: String, did: String, aile: String, sektor: String) {
        var b = apiBase
        if let q = b.firstIndex(of: "?") { b = String(b[..<q]) }
        if !b.hasSuffix("/") { b += "/" }
        taban = b
        self.did = did
        self.sektor = sektor
        self.aile = PanelAile.coz(aile, base: b)
        let c = URLSessionConfiguration.default
        c.httpCookieStorage = HTTPCookieStorage.shared
        c.httpShouldSetCookies = true
        c.httpCookieAcceptPolicy = .always
        session = URLSession(configuration: c)
    }

    var cihaz: String {
        let k = "panel_dev_\(did)"
        if let v = UserDefaults.standard.string(forKey: k) { return v }
        let v = UUID().uuidString
        UserDefaults.standard.set(v, forKey: k); return v
    }

    func url(_ ep: String) -> URL {
        URL(string: taban + "api/" + ep + (ep.contains("?") ? "&" : "?") + "d=" + did)!
    }

    @discardableResult
    func post(_ ep: String, _ body: [String: Any] = [:]) async -> [String: Any] {
        var r = URLRequest(url: url(ep)); r.httpMethod = "POST"; r.timeoutInterval = 30
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (d, _) = try? await session.data(for: r),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return j
    }

    func getArr(_ ep: String) async -> [[String: Any]] {
        guard let (d, _) = try? await session.data(from: url(ep)),
              let j = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
        return j
    }
    func getObj(_ ep: String) async -> [String: Any] {
        guard let (d, _) = try? await session.data(from: url(ep)),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return j
    }

    func giris(_ u: String, _ p: String) async {
        hata = ""; yukleniyor = true; defer { yukleniyor = false }
        let j = await post("login", ["username": u, "password": p, "device": cihaz, "remember": true])
        if j["ok"] as? Bool == true { rol = j["role"] as? String ?? ""; girisli = true }
        else if j["needotp"] as? Bool == true { otpGerek = true; otpHint = j["hint"] as? String ?? "" }
        else { hata = j["err"] as? String ?? "Giriş başarısız" }
    }
    func otpDogrula(_ kod: String) async {
        hata = ""; yukleniyor = true; defer { yukleniyor = false }
        let j = await post("verifydev", ["code": kod])
        if j["ok"] as? Bool == true { rol = j["role"] as? String ?? ""; girisli = true; otpGerek = false }
        else { hata = j["err"] as? String ?? "Kod hatalı" }
    }

    var sahip: Bool { rol == "owner" }
}

// MARK: - Router
struct IsletmePanelView: View {
    @EnvironmentObject var tema: Tema
    @StateObject private var api: PanelAPI
    let onKadi: String, onSifre: String
    @State private var u = "", p = "", kod = "", denendi = false

    init(apiBase: String, did: String, aile: String, sektor: String, kadi: String, sifre: String) {
        _api = StateObject(wrappedValue: PanelAPI(apiBase: apiBase, did: did, aile: aile, sektor: sektor))
        onKadi = kadi; onSifre = sifre
    }

    var body: some View {
        Group {
            if api.girisli {
                switch api.aile {
                case .restoran: RestoranPanel(api: api)
                case .randevu, .ogretmen: RandevuPanel(api: api)
                case .hukuk: HukukPanel(api: api)
                case .bilinmiyor: bilinmeyen
                }
            } else if api.otpGerek { PanelAuth.otp(api: api, kod: $kod, tema: tema) }
            else { PanelAuth.giris(api: api, u: $u, p: $p, tema: tema) }
        }
        .navigationTitle("İşletme Paneli").navigationBarTitleDisplayMode(.inline)
        .task {
            if !denendi, !onKadi.isEmpty, !onSifre.isEmpty {
                denendi = true; u = onKadi; p = onSifre
                await api.giris(onKadi, onSifre)
            }
        }
    }

    var bilinmeyen: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.folder").font(.system(size: 40)).foregroundStyle(.rvMut)
            Text("Bu işletme tipi için native panel hazırlanıyor.").foregroundStyle(.rvMut).multilineTextAlignment(.center)
        }.padding(40)
    }
}

// MARK: - Ortak: Giriş & OTP ekranları
enum PanelAuth {
    static func giris(api: PanelAPI, u: Binding<String>, p: Binding<String>, tema: Tema) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "building.2.crop.circle.fill").font(.system(size: 46)).foregroundStyle(tema.grad).padding(.top, 28)
                Text("İşletme Girişi").font(.title2.bold()).foregroundStyle(.rvText)
                TextField("Kullanıcı adı", text: u).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding().background(Color.rvCard, in: .rect(cornerRadius: 14))
                SecureField("Şifre", text: p).padding().background(Color.rvCard, in: .rect(cornerRadius: 14))
                if !api.hata.isEmpty { Text(api.hata).font(.caption).foregroundStyle(.orange) }
                Button { Task { await api.giris(u.wrappedValue, p.wrappedValue) } } label: {
                    HStack { if api.yukleniyor { ProgressView().tint(.white) }; Text("Giriş Yap").bold() }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(tema.grad, in: .rect(cornerRadius: 14))
                }.disabled(api.yukleniyor || u.wrappedValue.isEmpty || p.wrappedValue.isEmpty)
            }.padding()
        }
    }
    static func otp(api: PanelAPI, kod: Binding<String>, tema: Tema) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill").font(.system(size: 46)).foregroundStyle(tema.grad).padding(.top, 28)
                Text("Yeni Cihaz Doğrulaması").font(.title3.bold()).foregroundStyle(.rvText)
                Text("Telefonuna (***\(api.otpHint)) gelen kodu gir.").font(.caption).foregroundStyle(.rvMut)
                TextField("SMS kodu", text: kod).keyboardType(.numberPad)
                    .padding().background(Color.rvCard, in: .rect(cornerRadius: 14))
                if !api.hata.isEmpty { Text(api.hata).font(.caption).foregroundStyle(.orange) }
                Button { Task { await api.otpDogrula(kod.wrappedValue) } } label: {
                    Text("Doğrula").bold().foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(tema.grad, in: .rect(cornerRadius: 14))
                }.disabled(api.yukleniyor || kod.wrappedValue.count < 4)
            }.padding()
        }
    }
}

// MARK: - Ortak görsel parçalar
struct PanelChips: View {
    let sekmeler: [(String, String)]
    @Binding var secili: Int
    let tema: Tema
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(sekmeler.enumerated()), id: \.offset) { i, s in
                    Button { secili = i } label: {
                        Label(s.0, systemImage: s.1).font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(secili == i ? AnyShapeStyle(tema.grad) : AnyShapeStyle(Color.rvCard), in: .capsule)
                            .foregroundStyle(secili == i ? Color.white : Color.rvMut)
                    }
                }
            }.padding(.horizontal)
        }.padding(.vertical, 8)
    }
}

func panelKpi(_ t: String, _ v: String, _ ik: String, _ renk: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Image(systemName: ik).foregroundStyle(renk).font(.title2)
        Text(v).font(.title.bold()).foregroundStyle(.rvText)
        Text(t).font(.caption).foregroundStyle(.rvMut)
    }
    .frame(maxWidth: .infinity, alignment: .leading).padding()
    .background(Color.rvCard, in: .rect(cornerRadius: 16))
}

func panelKart<C: View>(@ViewBuilder _ icerik: () -> C) -> some View {
    VStack(alignment: .leading, spacing: 8) { icerik() }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rvCard, in: .rect(cornerRadius: 14))
}

// MARK: - Ortak: Personel sekmesi (tüm sektörler — /api/admins)
struct PersonelSekmesi: View {
    @ObservedObject var api: PanelAPI
    let tema: Tema
    @State private var me = "", devlock = false
    @State private var admins: [[String: Any]] = []
    @State private var yeniU = "", yeniP = "", hata = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if api.sahip {
                    panelKart {
                        Text("Yeni Personel Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                        TextField("Kullanıcı adı", text: $yeniU).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                        SecureField("Şifre (min 4)", text: $yeniP).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                        if !hata.isEmpty { Text(hata).font(.caption).foregroundStyle(.orange) }
                        Button { Task { await ekle() } } label: {
                            Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(tema.grad, in: .rect(cornerRadius: 10))
                        }.disabled(yeniU.count < 3 || yeniP.count < 4)
                    }
                }
                ForEach(Array(admins.enumerated()), id: \.offset) { _, a in
                    let usr = a["username"] as? String ?? ""
                    let rl = a["role"] as? String ?? ""
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(usr).font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text(rolAd(rl)).font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            if api.sahip && rl != "owner" {
                                Button { Task { _ = await api.post("admins/\(usr)/resetdev"); await yukle() } } label: {
                                    Image(systemName: "iphone.slash").foregroundStyle(.orange)
                                }
                                Button { Task { _ = await api.post("admins/\(usr)/delete"); await yukle() } } label: {
                                    Image(systemName: "trash").foregroundStyle(.red)
                                }.padding(.leading, 8)
                            }
                        }
                    }
                }
            }.padding()
        }
        .task { await yukle() }
    }

    func rolAd(_ r: String) -> String {
        switch r { case "owner": return "👑 Sahip"; case "manager": return "🧑‍💼 Yönetici"; default: return "👤 Personel" }
    }
    func yukle() async {
        let j = await api.getObj("admins")
        me = j["me"] as? String ?? ""
        devlock = j["devlock"] as? Bool ?? false
        admins = j["admins"] as? [[String: Any]] ?? []
    }
    func ekle() async {
        hata = ""
        let j = await api.post("admins", ["username": yeniU.lowercased(), "password": yeniP])
        if j["ok"] as? Bool == true { yeniU = ""; yeniP = ""; await yukle() }
        else { hata = j["err"] as? String ?? "Eklenemedi" }
    }
}

// MARK: - Ortak: Ayar sekmesi (marka adı + tema renkleri — /api/brand,/api/theme)
struct AyarSekmesi: View {
    @ObservedObject var api: PanelAPI
    let tema: Tema
    @State private var marka = "", c1 = "#7C5CF6", c2 = "#5B4BE8", bilgi = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                panelKart {
                    Text("İşletme Adı").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField("İşletme adı", text: $marka).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    Button { Task { let j = await api.post("brand", ["name": marka]); bilgi = j["ok"] as? Bool == true ? "Kaydedildi ✓" : "Hata" } } label: {
                        Text("Adı Kaydet").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(marka.isEmpty)
                }
                panelKart {
                    Text("Tema Renkleri (hex)").font(.subheadline.bold()).foregroundStyle(.rvText)
                    HStack {
                        TextField("#7C5CF6", text: $c1).autocorrectionDisabled().textInputAutocapitalization(.never)
                            .padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                        TextField("#5B4BE8", text: $c2).autocorrectionDisabled().textInputAutocapitalization(.never)
                            .padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    }
                    Button { Task { let j = await api.post("theme", ["c1": c1, "c2": c2]); bilgi = j["ok"] as? Bool == true ? "Tema güncellendi ✓" : "Hata" } } label: {
                        Text("Temayı Kaydet").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(tema.grad, in: .rect(cornerRadius: 10))
                    }
                }
                if !bilgi.isEmpty { Text(bilgi).font(.caption).foregroundStyle(.green) }
                Button(role: .destructive) { Task { _ = await api.post("logout"); api.girisli = false } } label: {
                    Text("Çıkış Yap").font(.caption.bold()).foregroundStyle(.red).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
            }.padding()
        }
    }
}
