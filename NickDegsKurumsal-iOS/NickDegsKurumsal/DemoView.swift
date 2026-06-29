import SwiftUI

private let DEMO_BASE = "https://nickdegs.com"

struct DemoView: View {
    let urun: Urun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Environment(\.dismiss) var dismiss

    @State private var adim = 0        // 0: form, 1: OTP, 2: hazır
    @State private var isletmeAd = ""
    @State private var ulke = ULKE_VARSAYILAN
    @State private var tel = ""
    @State private var sektor = "diger"
    @State private var otp = ""
    @State private var bekle = false
    @State private var hata = ""
    @State private var sonuc: [String: Any]? = nil

    let sektorler: [(String, String)] = [
        ("diger","🏢 Genel"),("lokanta","🍽️ Lokanta/Kafe"),("kafe","☕ Kafe"),
        ("otel","🏨 Otel"),("kuafor","💇 Kuaför/Berber"),("klinik","🩺 Klinik"),
        ("estetik","💆 Estetik"),("veteriner","🐾 Veteriner"),("spor","🏋️ Spor Salonu"),
        ("market","🛒 Market/Dükkan"),("hukuk","⚖️ Hukuk Bürosu"),("ogretmen","👨‍🏫 Öğretmen/Eğitim")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                LensFlare().opacity(0.6)
                ScrollView {
                    VStack(spacing: 22) {
                        Spacer(minLength: 8)
                        ikon
                        switch adim {
                        case 0: formAdimi
                        case 1: otpAdimi
                        default: basariAdimi
                        }
                        if !hata.isEmpty {
                            Text(hata).font(.caption).foregroundStyle(.orange)
                                .multilineTextAlignment(.center).padding(.horizontal)
                        }
                        Spacer()
                    }
                    .padding(24).frame(maxWidth: 480)
                }
            }
            .navigationTitle("1 Günlük Ücretsiz Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }.foregroundStyle(tema.c1)
                }
            }
        }
        .tint(tema.c1)
    }

    var ikon: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(tema.c1.opacity(0.15)).frame(width: 80, height: 80)
                Text(urun.ic).font(.system(size: 40))
            }
            Text(yerel.u(urun.ad)).font(.title2.bold()).foregroundStyle(.rvText)
                .multilineTextAlignment(.center)
            Text("Hiç ödeme yapmadan 1 gün tam erişim. Kart bilgisi gerekmez.")
                .font(.subheadline).foregroundStyle(.rvMut).multilineTextAlignment(.center)
            abuseBilgi
        }
    }

    var abuseBilgi: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle").font(.caption)
            Text("Her numara 7 günde 1 demo hakkına sahiptir.")
                .font(.caption2)
        }
        .foregroundStyle(.rvMut)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.rvCard, in: .rect(cornerRadius: 10))
    }

    // MARK: Adım 1 — İşletme bilgileri
    var formAdimi: some View {
        VStack(spacing: 14) {
            alan("İşletme adı", $isletmeAd, sym: "storefront.fill")

            // Sektör seçici
            VStack(alignment: .leading, spacing: 6) {
                Text("Sektör").font(.caption.bold()).foregroundStyle(.rvMut)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sektorler, id: \.0) { s in
                            Button { sektor = s.0 } label: {
                                Text(s.1).font(.caption.bold())
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .foregroundStyle(sektor == s.0 ? .white : .rvText)
                                    .background(sektor == s.0 ? tema.c1 : Color.rvCard,
                                                in: .rect(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(sektor == s.0 ? tema.c1 : Color.rvLine, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 2)
                }
            }

            // Telefon
            VStack(alignment: .leading, spacing: 6) {
                Text("Telefon (SMS doğrulama için)").font(.caption.bold()).foregroundStyle(.rvMut)
                HStack(spacing: 10) {
                    UlkeKodSecici(secili: $ulke)
                    Divider().frame(height: 22).overlay(Color.rvMut.opacity(0.4))
                    TextField("5xx xxx xx xx", text: $tel)
                        .keyboardType(.phonePad).autocorrectionDisabled().foregroundStyle(.rvText)
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(Color.rvCard, in: .rect(cornerRadius: 14))
            }

            demoButon("SMS Kodu Gönder") { Task { await smsTalep() } }
                .disabled(isletmeAd.trimmingCharacters(in: .whitespaces).isEmpty ||
                          tel.trimmingCharacters(in: .whitespaces).count < 5)
        }
    }

    // MARK: Adım 2 — OTP
    var otpAdimi: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Doğrulama kodu").font(.headline.bold()).foregroundStyle(.rvText)
                Text("Numaranıza 6 haneli kod gönderildi.").font(.caption).foregroundStyle(.rvMut)
            }
            TextField("_ _ _ _ _ _", text: $otp)
                .keyboardType(.numberPad).autocorrectionDisabled()
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center).foregroundStyle(.rvText)
                .padding(18)
                .background(Color.rvCard, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(tema.c1.opacity(0.5), lineWidth: 1))
            demoButon("Doğrula & Demo Başlat") { Task { await smsDogrula() } }
                .disabled(otp.trimmingCharacters(in: .whitespaces).count < 4)
            Button("← Numarayı değiştir") { adim = 0; otp = ""; hata = "" }
                .font(.caption).foregroundStyle(tema.c2)
        }
    }

    // MARK: Adım 3 — Başarı
    var basariAdimi: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(.green)
            Text("Demo sistemin hazır! 🎉").font(.title3.bold()).foregroundStyle(.rvText)
                .multilineTextAlignment(.center)
            Text("24 saat tam erişim. Süre dolunca sistem otomatik kapanır.")
                .font(.caption).foregroundStyle(.rvMut).multilineTextAlignment(.center)
            if let s = sonuc {
                if let url = s["url"] as? String, !url.isEmpty { bilgiKart("Panel URL", url) }
                if let k = s["kadi"] as? String,  !k.isEmpty  { bilgiKart("Kullanıcı adı", k) }
                if let p = s["sifre"] as? String, !p.isEmpty  { bilgiKart("Şifre", p) }
                if let d = s["dashboard_kod"] as? String, !d.isEmpty { bilgiKart("Dashboard kodu", d) }
            }
            Text("NickDegs Dashboard uygulamasından bu bilgilerle giriş yapabilirsin.")
                .font(.caption2).foregroundStyle(.rvMut).multilineTextAlignment(.center)
            Button("Tamam") { dismiss() }
                .font(.headline.bold()).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(tema.grad, in: .rect(cornerRadius: 18))
                .padding(.top, 6)
        }
    }

    func bilgiKart(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k).font(.caption2).foregroundStyle(.rvMut)
            Text(v).font(.subheadline.bold()).foregroundStyle(tema.c1).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(Color.rvCard, in: .rect(cornerRadius: 14))
    }

    func alan(_ ipucu: String, _ bag: Binding<String>, sym: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: sym).foregroundStyle(.rvMut).frame(width: 22)
            TextField(ipucu, text: bag).foregroundStyle(.rvText).autocorrectionDisabled()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.rvCard, in: .rect(cornerRadius: 14))
    }

    func demoButon(_ baslik: String, _ aksiyon: @escaping () -> Void) -> some View {
        Button(action: aksiyon) {
            HStack(spacing: 8) {
                if bekle { ProgressView().tint(.white) }
                Image(systemName: "play.circle.fill")
                Text(baslik).font(.headline.bold())
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(tema.grad, in: .rect(cornerRadius: 18))
            .shadow(color: tema.c1.opacity(0.4), radius: 14, y: 6)
        }
        .disabled(bekle)
    }

    // MARK: API
    func smsTalep() async {
        hata = ""; bekle = true; defer { bekle = false }
        let numara = tamNumara(ulke.kod, tel)
        let body: [String: Any] = [
            "tel": numara.filter { $0.isNumber },
            "isletme_ad": isletmeAd.trimmingCharacters(in: .whitespaces),
            "sektor": sektor
        ]
        guard let url = URL(string: DEMO_BASE + "/api/demo/request") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (d, _) = try? await URLSession.shared.data(for: req),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            hata = "Bağlantı hatası"; return
        }
        if j["ok"] as? Bool == true { adim = 1 }
        else { hata = (j["err"] as? String) ?? "Hata oluştu" }
    }

    func smsDogrula() async {
        hata = ""; bekle = true; defer { bekle = false }
        let numara = tamNumara(ulke.kod, tel)
        let body: [String: Any] = ["tel": numara.filter { $0.isNumber }, "kod": otp]
        guard let url = URL(string: DEMO_BASE + "/api/demo/verify") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (d, _) = try? await URLSession.shared.data(for: req),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            hata = "Bağlantı hatası"; return
        }
        if j["ok"] as? Bool == true { sonuc = j; adim = 2 }
        else { hata = (j["err"] as? String) ?? "Doğrulama hatası" }
    }
}
