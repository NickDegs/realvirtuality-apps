import SwiftUI

struct LoginView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var oturum: Oturum
    @State private var mod = 0            // 0: şifre, 1: SMS
    @State private var kod = ""           // işletme kodu / telefon
    @State private var sifre = ""
    @State private var smsKod = ""
    @State private var smsGonderildi = false
    @State private var gelismis = false
    @State private var host = "https://nickdegs.com"
    @State private var hata = ""
    @State private var bekle = false

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            LensFlare()
            ScrollView {
                VStack(spacing: 18) {
                    Spacer(minLength: 60)
                    Image(systemName: "diamond.fill").font(.system(size: 54)).foregroundStyle(tema.grad).shimmer()
                    Text("NickDegs Dashboard").font(.largeTitle.bold()).foregroundStyle(.rvText)
                    Text("İşletme yönetim paneline giriş").font(.subheadline).foregroundStyle(.rvMut)

                    // Mod seçici
                    Picker("", selection: $mod) {
                        Text("Şifre ile").tag(0); Text("SMS ile").tag(1)
                    }.pickerStyle(.segmented).padding(.top, 6)

                    if mod == 0 {
                        alan("İşletme kodu veya telefon", $kod, sym: "person.text.rectangle")
                        alan("Şifre", $sifre, sym: "lock.fill", gizli: true)
                        anaButon("Giriş Yap") { Task { await sifreGiris() } }
                    } else {
                        alan("+90 5xx... (ülke kodlu telefon)", $kod, sym: "phone.fill", klavye: .phonePad)
                        if smsGonderildi {
                            alan("SMS kodu", $smsKod, sym: "number", klavye: .numberPad)
                            anaButon("Doğrula & Giriş") { Task { await smsDogrula() } }
                            Button("← Numarayı değiştir") { smsGonderildi = false; smsKod = "" }.font(.caption).foregroundStyle(tema.c2)
                        } else {
                            anaButon("SMS Kodu Gönder") { Task { await smsGonder() } }
                        }
                    }

                    if !hata.isEmpty {
                        Text(hata).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center)
                    }

                    // Gelişmiş: host (white-label / self-host)
                    DisclosureGroup(isExpanded: $gelismis) {
                        alan("Sunucu adresi", $host, sym: "server.rack")
                    } label: {
                        Text("Gelişmiş (sunucu)").font(.caption).foregroundStyle(.rvMut)
                    }
                    .tint(tema.c2).padding(.top, 4)

                    Text("Her işletme yalnızca kendi panelini görür. Veriler izole ve şifrelidir.")
                        .font(.caption2).foregroundStyle(.rvMut).multilineTextAlignment(.center).padding(.top, 8)
                    Spacer()
                }
                .padding(24).frame(maxWidth: 480)
            }
        }
    }

    func alan(_ ipucu: String, _ bag: Binding<String>, sym: String, gizli: Bool = false, klavye: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: sym).foregroundStyle(.rvMut).frame(width: 22)
            if gizli { SecureField(ipucu, text: bag).foregroundStyle(.rvText) }
            else { TextField(ipucu, text: bag).foregroundStyle(.rvText).autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(klavye) }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    func anaButon(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 8) {
                if bekle { ProgressView().tint(.white) }
                Text(t).font(.headline.bold())
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(tema.grad, in: .rect(cornerRadius: 16))
            .shadow(color: tema.c1.opacity(0.4), radius: 14, y: 6)
        }.disabled(bekle).padding(.top, 4)
    }

    // MARK: API
    func istek(_ yol: String, _ govde: [String:Any]) async -> [String:Any] {
        let h = host.hasPrefix("http") ? host : "https://" + host
        guard let url = URL(string: h + yol) else { return ["err":"adres"] }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 25
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: govde)
        guard let (d, _) = try? await URLSession.shared.data(for: r),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String:Any] else { return ["err":"baglanti"] }
        return j
    }
    func sifreGiris() async {
        hata = ""; bekle = true; defer { bekle = false }
        let j = await istek("/api/panel/login", ["kod": kod, "sifre": sifre])
        if j["ok"] as? Bool == true, let tok = j["token"] as? String { oturum.host = host; oturum.girisYap(token: tok) }
        else { hata = (j["mesaj"] as? String) ?? "Giriş başarısız. Bilgileri kontrol et." }
    }
    func smsGonder() async {
        hata = ""; bekle = true; defer { bekle = false }
        let j = await istek("/api/panel/sms", ["tel": kod])
        if j["ok"] as? Bool == true { smsGonderildi = true } else { hata = (j["mesaj"] as? String) ?? "SMS gönderilemedi." }
    }
    func smsDogrula() async {
        hata = ""; bekle = true; defer { bekle = false }
        let j = await istek("/api/panel/sms-dogrula", ["tel": kod, "kod": smsKod])
        if j["ok"] as? Bool == true, let tok = j["token"] as? String { oturum.host = host; oturum.girisYap(token: tok) }
        else { hata = (j["mesaj"] as? String) ?? "Kod doğrulanamadı." }
    }
}
