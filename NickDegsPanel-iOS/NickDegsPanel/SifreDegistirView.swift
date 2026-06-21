import SwiftUI

struct SifreDegistirView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var oturum: Oturum
    @Environment(\.dismiss) var dismiss
    @State private var tel = ""
    @State private var smsKod = ""
    @State private var yeni = ""
    @State private var yeni2 = ""
    @State private var smsGonderildi = false
    @State private var mesaj = ""
    @State private var basarili = false
    @State private var bekle = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.rotation").font(.system(size: 46)).foregroundStyle(tema.grad).shimmer().padding(.top, 30)
                        Text("Şifre Değiştir").font(.title2.bold()).foregroundStyle(.rvText)
                        Text("Güvenlik için önce telefonunu SMS ile doğrula, sonra yeni şifreni belirle.")
                            .font(.subheadline).foregroundStyle(.rvMut).multilineTextAlignment(.center).padding(.horizontal, 8)

                        alan("+90 5xx... (kayıtlı telefon)", $tel, sym: "phone.fill", klavye: .phonePad)
                        if !smsGonderildi {
                            anaButon("SMS Doğrulama Gönder") { Task { await smsGonder() } }
                        } else {
                            alan("SMS kodu", $smsKod, sym: "number", klavye: .numberPad)
                            alan("Yeni şifre (en az 6 karakter)", $yeni, sym: "lock.fill", gizli: true)
                            alan("Yeni şifre (tekrar)", $yeni2, sym: "lock.fill", gizli: true)
                            anaButon("Şifreyi Değiştir") { Task { await degistir() } }
                            Button("← Numarayı değiştir") { smsGonderildi = false; smsKod = "" }.font(.caption).foregroundStyle(tema.c2)
                        }
                        if !mesaj.isEmpty {
                            Text(mesaj).font(.caption).foregroundStyle(basarili ? .green : .orange).multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(24).frame(maxWidth: 480)
                }
            }
            .navigationTitle("Güvenlik").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(tema.c1) } }
        }
        .tint(tema.c1)
    }

    func alan(_ ip: String, _ bag: Binding<String>, sym: String, gizli: Bool = false, klavye: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: sym).foregroundStyle(.rvMut).frame(width: 22)
            if gizli { SecureField(ip, text: bag).foregroundStyle(.rvText) }
            else { TextField(ip, text: bag).foregroundStyle(.rvText).autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(klavye) }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
    func anaButon(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 8) { if bekle { ProgressView().tint(.white) }; Text(t).font(.headline.bold()) }
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(tema.grad, in: .rect(cornerRadius: 16)).shadow(color: tema.c1.opacity(0.4), radius: 14, y: 6)
        }.disabled(bekle).padding(.top, 4)
    }

    func istek(_ yol: String, _ govde: [String:Any]) async -> [String:Any] {
        let h = oturum.host.hasPrefix("http") ? oturum.host : "https://" + oturum.host
        guard let url = URL(string: h + yol) else { return ["err":"adres"] }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 25
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: govde)
        guard let (d, _) = try? await URLSession.shared.data(for: r),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String:Any] else { return ["err":"baglanti"] }
        return j
    }
    func smsGonder() async {
        mesaj = ""; bekle = true; defer { bekle = false }
        let j = await istek("/api/panel/sms", ["tel": tel])
        if j["ok"] as? Bool == true { smsGonderildi = true; mesaj = "Doğrulama kodu telefonuna gönderildi." ; basarili = true }
        else { mesaj = (j["mesaj"] as? String) ?? "SMS gönderilemedi."; basarili = false }
    }
    func degistir() async {
        mesaj = ""
        guard yeni == yeni2 else { mesaj = "Şifreler eşleşmiyor."; basarili = false; return }
        guard yeni.count >= 6 else { mesaj = "Yeni şifre en az 6 karakter olmalı."; basarili = false; return }
        bekle = true; defer { bekle = false }
        let j = await istek("/api/panel/sifre-degistir", ["tel": tel, "kod": smsKod, "yeni_sifre": yeni])
        if j["ok"] as? Bool == true {
            mesaj = "✓ Şifren değiştirildi."; basarili = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        } else { mesaj = (j["mesaj"] as? String) ?? "Değiştirilemedi."; basarili = false }
    }
}
