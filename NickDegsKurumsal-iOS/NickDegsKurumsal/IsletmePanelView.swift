import SwiftUI
import PhotosUI
import Charts

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

    // Multipart dosya yükleme (logo / belge) — opsiyonel metin alanlarıyla
    func upload(_ ep: String, field: String, filename: String, mime: String,
                fileData: Data, extra: [String: String] = [:]) async -> [String: Any] {
        let boundary = "ndg-\(UUID().uuidString)"
        var r = URLRequest(url: url(ep)); r.httpMethod = "POST"; r.timeoutInterval = 90
        r.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var b = Data()
        func add(_ s: String) { b.append(s.data(using: .utf8)!) }
        for (k, v) in extra {
            add("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n")
        }
        add("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\nContent-Type: \(mime)\r\n\r\n")
        b.append(fileData)
        add("\r\n--\(boundary)--\r\n")
        guard let (d, _) = try? await session.upload(for: r, from: b),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return j
    }

    // Dosya indirme (şifreli belge kasası → geçici dosya URL'i, paylaşım sayfasına)
    func indir(_ ep: String, adKaydet: String) async -> URL? {
        guard let (d, _) = try? await session.data(from: url(ep)) else { return nil }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(adKaydet)
        try? d.write(to: u)
        return u
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
    @State private var u = ""
    @State private var p = ""
    @State private var kod = ""
    @State private var denendi = false

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
            } else if api.otpGerek { PanelOtp(api: api, kod: $kod) }
            else { PanelGiris(api: api, u: $u, p: $p) }
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
struct PanelGiris: View {
    @ObservedObject var api: PanelAPI
    @EnvironmentObject var tema: Tema
    @Binding var u: String
    @Binding var p: String
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "building.2.crop.circle.fill").font(.system(size: 46)).foregroundStyle(tema.grad).padding(.top, 28)
                Text("İşletme Girişi").font(.title2.bold()).foregroundStyle(.rvText)
                TextField("Kullanıcı adı", text: $u).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding().background(Color.rvCard, in: .rect(cornerRadius: 14))
                SecureField("Şifre", text: $p).padding().background(Color.rvCard, in: .rect(cornerRadius: 14))
                if !api.hata.isEmpty { Text(api.hata).font(.caption).foregroundStyle(.orange) }
                Button { Task { await api.giris(u, p) } } label: {
                    HStack { if api.yukleniyor { ProgressView().tint(.white) }; Text("Giriş Yap").bold() }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(tema.grad, in: .rect(cornerRadius: 14))
                }.disabled(api.yukleniyor || u.isEmpty || p.isEmpty)
            }.padding()
        }
    }
}

struct PanelOtp: View {
    @ObservedObject var api: PanelAPI
    @EnvironmentObject var tema: Tema
    @Binding var kod: String
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill").font(.system(size: 46)).foregroundStyle(tema.grad).padding(.top, 28)
                Text("Yeni Cihaz Doğrulaması").font(.title3.bold()).foregroundStyle(.rvText)
                Text("Telefonuna (***\(api.otpHint)) gelen kodu gir.").font(.caption).foregroundStyle(.rvMut)
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
    @State private var me = ""
    @State private var devlock = false
    @State private var admins: [[String: Any]] = []
    @State private var yeniU = ""
    @State private var yeniP = ""
    @State private var hata = ""

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
    @State private var marka = ""
    @State private var c1 = "#7C5CF6"
    @State private var c2 = "#5B4BE8"
    @State private var bilgi = ""
    @State private var logoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                panelKart {
                    Text("Logo").font(.subheadline.bold()).foregroundStyle(.rvText)
                    PhotosPicker(selection: $logoItem, matching: .images) {
                        Label("Logo Yükle / Değiştir", systemImage: "photo.badge.plus")
                            .font(.caption.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(tema.grad, in: .rect(cornerRadius: 10))
                    }
                }
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
        .onChange(of: logoItem) { _, yeni in
            Task {
                guard let d = try? await yeni?.loadTransferable(type: Data.self) else { return }
                let j = await api.upload("logo", field: "logo", filename: "logo.jpg", mime: "image/jpeg", fileData: d)
                bilgi = (j["ok"] as? Bool == true) ? "Logo yüklendi ✓" : "Logo yüklenemedi"
            }
        }
    }
}

// MARK: - Rapor (7 gün ciro grafiği + en çok satan) — tüm sektörlerde özet'te
struct RaporKart: View {
    @ObservedObject var api: PanelAPI
    let tema: Tema
    @State private var gunluk: [[String: Any]] = []
    @State private var top: [[String: Any]] = []
    @State private var ayGelir = 0
    @State private var ayAdet = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar").foregroundStyle(tema.c2)
                Text("Bu Ay").font(.subheadline.bold()).foregroundStyle(.rvText)
                Spacer()
                Text("₺\(ayGelir) · \(ayAdet) işlem").font(.subheadline.bold()).foregroundStyle(tema.c1)
            }
            Divider().overlay(Color.rvLine)
            Text("Son 7 Gün Ciro").font(.subheadline.bold()).foregroundStyle(.rvText)
            if gunluk.isEmpty {
                Text("Henüz veri yok").font(.caption).foregroundStyle(.rvMut).frame(height: 120)
            } else {
                Chart {
                    ForEach(Array(gunluk.enumerated()), id: \.offset) { _, g in
                        BarMark(x: .value("Gün", String((g["gun"] as? String ?? "").suffix(5))),
                                y: .value("Ciro", g["gelir"] as? Int ?? 0))
                        .foregroundStyle(tema.grad)
                    }
                }.frame(height: 150)
            }
            if !top.isEmpty {
                Text("En Çok Satan").font(.subheadline.bold()).foregroundStyle(.rvText).padding(.top, 6)
                ForEach(Array(top.enumerated()), id: \.offset) { i, t in
                    HStack {
                        Text("\(i + 1).").foregroundStyle(.rvMut)
                        Text(t["ad"] as? String ?? "-").foregroundStyle(.rvText).lineLimit(1)
                        Spacer()
                        Text("\(t["adet"] as? Int ?? 0)x").font(.caption.bold()).foregroundStyle(tema.c2)
                    }.font(.caption)
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rvCard, in: .rect(cornerRadius: 16))
        .task {
            let j = await api.getObj("stats-range")
            gunluk = j["gunluk"] as? [[String: Any]] ?? []
            top = j["top"] as? [[String: Any]] ?? []
            ayGelir = j["ay_gelir"] as? Int ?? 0
            ayAdet = j["ay_adet"] as? Int ?? 0
        }
    }
}
