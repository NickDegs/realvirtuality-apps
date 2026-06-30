import SwiftUI
import UIKit
import PhotosUI
import Charts
import CoreImage.CIFilterBuiltins

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
        oturumGeriYukle()   // kapat-aç'ta oturumu geri yükle (tekrar SMS login isteme)
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

    // GÜVENLİK: her isteğe App Attest token'ı (X-Attest-Token) — sideload/tamper edilmiş app token üretemez.
    private func req(_ ep: String) -> URLRequest {
        var r = URLRequest(url: url(ep))
        for (k, v) in AppAttest.shared.header { r.setValue(v, forHTTPHeaderField: k) }
        return r
    }

    @discardableResult
    func post(_ ep: String, _ body: [String: Any] = [:]) async -> [String: Any] {
        var r = req(ep); r.httpMethod = "POST"; r.timeoutInterval = 30
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
        var r = req(ep); r.httpMethod = "POST"; r.timeoutInterval = 90
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
        guard let (d, _) = try? await session.data(for: req(ep)) else { return nil }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(adKaydet)
        try? d.write(to: u)
        return u
    }

    func getArr(_ ep: String) async -> [[String: Any]] {
        guard let (d, _) = try? await session.data(for: req(ep)),
              let j = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
        return j
    }
    func getObj(_ ep: String) async -> [String: Any] {
        guard let (d, _) = try? await session.data(for: req(ep)),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return j
    }

    func giris(_ u: String, _ p: String) async {
        hata = ""; yukleniyor = true; defer { yukleniyor = false }
        let j = await post("login", ["username": u, "password": p, "device": cihaz, "remember": true])
        if j["ok"] as? Bool == true { rol = j["role"] as? String ?? ""; girisli = true; oturumKaydet() }
        else if j["needotp"] as? Bool == true { otpGerek = true; otpHint = j["hint"] as? String ?? "" }
        else { hata = j["err"] as? String ?? "Giriş başarısız" }
    }
    func otpDogrula(_ kod: String) async {
        hata = ""; yukleniyor = true; defer { yukleniyor = false }
        let j = await post("verifydev", ["code": kod])
        if j["ok"] as? Bool == true { rol = j["role"] as? String ?? ""; girisli = true; otpGerek = false; oturumKaydet() }
        else { hata = j["err"] as? String ?? "Kod hatalı" }
    }

    // ── Oturum kalıcılığı (Barış 2026-06-30): kapat-aç'ta tekrar SMS login istemesin ──
    private var oturumKey: String { "biz_oturum_" + (URL(string: taban)?.host ?? "x") }
    func oturumKaydet() {
        guard let url = URL(string: taban) else { return }
        let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        let arr: [[String: String]] = cookies.map { ["n": $0.name, "v": $0.value, "d": $0.domain, "p": $0.path] }
        if let d = try? JSONSerialization.data(withJSONObject: arr) {
            UserDefaults.standard.set(d, forKey: oturumKey)
            UserDefaults.standard.set(rol, forKey: oturumKey + "_rol")
        }
    }
    /// Launch'ta çağrılır: kayıtlı oturum cookie'lerini 30-gün kalıcı olarak geri yükler + girisli=true.
    func oturumGeriYukle() {
        guard let d = UserDefaults.standard.data(forKey: oturumKey),
              let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: String]], !arr.isEmpty else { return }
        for c in arr {
            if let n = c["n"], let v = c["v"], let dom = c["d"], let p = c["p"],
               let cookie = HTTPCookie(properties: [
                .name: n, .value: v, .domain: dom, .path: p,
                .expires: Date(timeIntervalSinceNow: 86400 * 30)]) {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
        rol = UserDefaults.standard.string(forKey: oturumKey + "_rol") ?? rol
        girisli = true   // optimist: oturum geçerli; sunucu reddederse kullanıcı tekrar girer
    }
    func oturumSil() {
        UserDefaults.standard.removeObject(forKey: oturumKey)
        UserDefaults.standard.removeObject(forKey: oturumKey + "_rol")
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
    @State private var bTel = ""
    @State private var bAdres = ""
    @State private var bSaat = ""
    @State private var bAciklama = ""

    var musteriURL: String {
        switch api.aile {
        case .restoran: return api.taban + "siparis?d=" + api.did
        case .randevu, .ogretmen: return api.taban + "randevu?d=" + api.did
        default: return ""
        }
    }
    func qrUret(_ s: String) -> UIImage? {
        let ctx = CIContext()
        let f = CIFilter.qrCodeGenerator()
        f.setValue(Data(s.utf8), forKey: "inputMessage")
        guard let ci = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !musteriURL.isEmpty {
                    panelKart {
                        Text(api.aile == .restoran ? "Müşteri Sipariş QR" : "Müşteri Randevu QR").font(.subheadline.bold()).foregroundStyle(.rvText)
                        if let qr = qrUret(musteriURL) {
                            Image(uiImage: qr).interpolation(.none).resizable().scaledToFit()
                                .frame(width: 180, height: 180).padding(8).background(Color.white, in: .rect(cornerRadius: 12))
                                .frame(maxWidth: .infinity)
                            ShareLink(item: Image(uiImage: qr), preview: SharePreview("Müşteri QR", image: Image(uiImage: qr))) {
                                Label("QR'ı Kaydet / Yazdır", systemImage: "square.and.arrow.up").font(.caption.bold()).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                            }
                        }
                        Text("Masalara yapıştır — müşteri okutup \(api.aile == .restoran ? "sipariş verir" : "randevu alır").")
                            .font(.caption2).foregroundStyle(.rvMut)
                    }
                }
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
                    Text("İşletme Bilgileri").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField("Telefon", text: $bTel).keyboardType(.phonePad).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    TextField("Adres", text: $bAdres, axis: .vertical).lineLimit(1...3).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    TextField("Çalışma saatleri (ör. 09:00-22:00)", text: $bSaat).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    TextField("Kısa açıklama", text: $bAciklama, axis: .vertical).lineLimit(1...3).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    Button { Task { let j = await api.post("info", ["tel": bTel, "adres": bAdres, "saat": bSaat, "aciklama": bAciklama]); bilgi = j["ok"] as? Bool == true ? "Bilgiler kaydedildi ✓" : "Hata" } } label: {
                        Text("Bilgileri Kaydet").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(tema.grad, in: .rect(cornerRadius: 10))
                    }
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
                Button(role: .destructive) { Task { _ = await api.post("logout"); api.girisli = false; api.oturumSil() } } label: {
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
        .task {
            let j = await api.getObj("info")
            bTel = j["tel"] as? String ?? ""; bAdres = j["adres"] as? String ?? ""
            bSaat = j["saat"] as? String ?? ""; bAciklama = j["aciklama"] as? String ?? ""
        }
    }
}

// MARK: - Kupon / İndirim (kampanya kodları — satışı artırır)
struct KuponSekmesi: View {
    @ObservedObject var api: PanelAPI
    let tema: Tema
    @State private var kuponlar: [[String: Any]] = []
    @State private var kod = ""
    @State private var tip = "yuzde"
    @State private var deger = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Kupon Oluştur").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField("Kod (ör. HOSGELDIN)", text: $kod).autocorrectionDisabled().textInputAutocapitalization(.characters)
                        .padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    HStack {
                        Picker("", selection: $tip) { Text("% Yüzde").tag("yuzde"); Text("₺ Tutar").tag("tutar") }.pickerStyle(.segmented)
                        TextField(tip == "yuzde" ? "%" : "₺", text: $deger).keyboardType(.numberPad)
                            .frame(width: 72).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    }
                    Button { Task { _ = await api.post("coupon", ["kod": kod, "tip": tip, "deger": Int(deger) ?? 0]); kod = ""; deger = ""; await yukle() } } label: {
                        Text("Oluştur").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(kod.isEmpty || (Int(deger) ?? 0) <= 0)
                }
                if kuponlar.isEmpty { Text("Henüz kupon yok").foregroundStyle(.rvMut).padding(.top, 20) }
                ForEach(Array(kuponlar.enumerated()), id: \.offset) { _, k in
                    let id = k["id"] as? Int ?? 0
                    let aktif = (k["aktif"] as? Int ?? 1) == 1
                    let yuzdeMi = (k["tip"] as? String ?? "") == "yuzde"
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(k["kod"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text("\(yuzdeMi ? "%" : "₺")\(k["deger"] as? Int ?? 0) indirim · \(k["kullanim"] as? Int ?? 0) kullanım").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Button { Task { _ = await api.post("coupon/\(id)/toggle"); await yukle() } } label: {
                                Text(aktif ? "Aktif" : "Pasif").font(.caption.bold()).foregroundStyle(aktif ? .green : .orange)
                                    .padding(.horizontal, 10).padding(.vertical, 5).background((aktif ? Color.green : Color.orange).opacity(0.15), in: .capsule)
                            }
                            Button { Task { _ = await api.post("coupon/\(id)/delete"); await yukle() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }.padding(.leading, 6)
                        }
                    }
                }
            }.padding()
        }
        .task { await yukle() }
    }
    func yukle() async { kuponlar = await api.getArr("coupons") }
}

// MARK: - Rapor (7 gün ciro grafiği + en çok satan) — tüm sektörlerde özet'te
struct RaporKart: View {
    @ObservedObject var api: PanelAPI
    let tema: Tema
    @State private var gunluk: [[String: Any]] = []
    @State private var top: [[String: Any]] = []
    @State private var ayGelir = 0
    @State private var ayAdet = 0
    @State private var brand = ""
    @State private var paylasImg: PaylasGorsel?

    var icerik: some View {
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            icerik
            Button { paylasImg = gorselUret() } label: {
                Label("Raporu Paylaş", systemImage: "square.and.arrow.up")
                    .font(.caption.bold()).foregroundStyle(tema.c1)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(tema.c1.opacity(0.12), in: .rect(cornerRadius: 10))
            }.padding(.top, 4)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rvCard, in: .rect(cornerRadius: 16))
        .sheet(item: $paylasImg) { p in PaylasSheet(image: p.img) }
        .task {
            let j = await api.getObj("stats-range")
            gunluk = j["gunluk"] as? [[String: Any]] ?? []
            top = j["top"] as? [[String: Any]] ?? []
            ayGelir = j["ay_gelir"] as? Int ?? 0
            ayAdet = j["ay_adet"] as? Int ?? 0
            let info = await api.getObj("info")
            brand = info["brand"] as? String ?? ""
        }
    }

    @MainActor func gorselUret() -> PaylasGorsel? {
        let bugun: String = { let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; f.locale = Locale(identifier: "tr_TR"); return f.string(from: Date()) }()
        let kart = VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(brand.isEmpty ? "İşletmem" : brand).font(.title3.bold()).foregroundStyle(.white)
                Spacer()
                Text(bugun).font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            icerik
            HStack(spacing: 6) {
                Image(systemName: "shield.fill").font(.caption2)
                Text("NickDegs ile yönetiliyor").font(.caption2)
            }.foregroundStyle(.white.opacity(0.55))
        }
        .padding(22).frame(width: 380, alignment: .leading)
        .background(Color.rvBg)
        .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: kart)
        r.scale = 3
        guard let img = r.uiImage else { return nil }
        return PaylasGorsel(img: img)
    }
}

struct PaylasGorsel: Identifiable { let id = UUID(); let img: UIImage }

struct PaylasSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
