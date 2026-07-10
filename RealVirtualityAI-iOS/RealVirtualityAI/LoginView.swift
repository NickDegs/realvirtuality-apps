import SwiftUI

struct LoginView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var yerel: Yerel
    @Environment(\.dismiss) var dismiss
    @State private var tel = ""
    @State private var ulke = ULKE_VARSAYILAN
    @State private var kod = ""
    @State private var adim = 0          // 0: telefon, 1: kod
    @State private var hata = ""
    @State private var bekle = false
    @State private var bilgi = ""
    @State private var silOnay = false

    var body: some View {
        ZStack {
            Color.rvBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if api.girisli {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 54)).foregroundStyle(.rvViolet)
                        Text(api.tel ?? api.email ?? "").font(.headline).foregroundStyle(.rvText)
                        Text("⚡ \(api.kredi) kredi").foregroundStyle(.rvCyan)
                        Text("Oturum iCloud ile cihazların arasında senkron.").font(.caption2).foregroundStyle(.rvMut).multilineTextAlignment(.center)
                        Button(yerel.t("cikisYap")) { Task { await api.cikis(); dismiss() } }
                            .padding().frame(maxWidth: .infinity)
                            .rvGlass(14).foregroundStyle(.rvText)
                        Button(role: .destructive) { silOnay = true } label: {
                            Text(yerel.secim == "tr" ? "Hesabımı Sil" : "Delete Account")
                                .padding().frame(maxWidth: .infinity)
                        }.foregroundStyle(.red)
                        .confirmationDialog(yerel.secim == "tr" ? "Hesabın ve tüm üretimlerin kalıcı olarak silinsin mi? Bu işlem geri alınamaz." : "Permanently delete your account and all your creations? This cannot be undone.", isPresented: $silOnay, titleVisibility: .visible) {
                            Button(yerel.secim == "tr" ? "Hesabı Sil" : "Delete Account", role: .destructive) { Task { if await api.hesapSil() { dismiss() } } }
                            Button(yerel.secim == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {}
                        }
                    } else {
                        Image(systemName: "sparkles").font(.system(size: 46)).foregroundStyle(.linearGradient(colors: [.rvViolet, .rvCyan], startPoint: .leading, endPoint: .trailing))
                        Text(yerel.t("girisBaslik")).font(.title2.bold()).foregroundStyle(.rvText)
                        Text(adim == 0 ? yerel.p("telefon") : yerel.p("smsKodu"))
                            .font(.subheadline).foregroundStyle(.rvMut).multilineTextAlignment(.center)

                        if adim == 0 {
                            HStack(spacing: 10) {
                                UlkeKodSecici(secili: $ulke)
                                Divider().frame(height: 22)
                                TextField("5xx xxx xx xx", text: $tel).keyboardType(.phonePad)
                                    .foregroundStyle(.rvText).autocorrectionDisabled()
                            }
                            .padding().rvGlass(14)
                        } else {
                            TextField(yerel.p("smsKodu"), text: $kod).keyboardType(.numberPad)
                                .multilineTextAlignment(.center).font(.title3)
                                .padding().rvGlass(14).foregroundStyle(.rvText)
                        }

                        if !bilgi.isEmpty { Text(bilgi).font(.caption).foregroundStyle(.rvCyan).multilineTextAlignment(.center) }
                        if !hata.isEmpty { Text(hata).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center) }

                        anaButon(adim == 0 ? yerel.p("kodGonder") : yerel.p("dogrulaGiris")) { Task { await ileri() } }

                        if adim == 1 {
                            Button("← " + yerel.p("telefon")) { adim = 0; kod = ""; hata = ""; bilgi = "" }
                                .font(.caption).foregroundStyle(.rvCyan)
                        }
                        Text("Telefon numaranla giriş yaparsın. Kredi ve üretimlerin hesabına bağlı, cihazlar arası senkron.")
                            .font(.caption2).foregroundStyle(.rvMut).multilineTextAlignment(.center).padding(.top, 4)
                    }
                }
                .padding(24)
            }
        }
        .presentationDetents([.medium, .large])
    }

    func anaButon(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 8) {
                if bekle { ProgressView().tint(.rvBg) }
                Text(t).font(.headline.bold())
            }
            .foregroundStyle(.rvBg).frame(maxWidth: .infinity).padding()
            .background(.linearGradient(colors: [.rvViolet, .rvCyan], startPoint: .leading, endPoint: .trailing))
            .clipShape(.rect(cornerRadius: 14))
            .opacity(bekle ? 0.7 : 1)
        }.disabled(bekle).padding(.top, 2)
    }

    func ileri() async {
        hata = ""; bilgi = ""; bekle = true; defer { bekle = false }
        let tam = tamNumara(ulke.kod, tel)   // +905xx...
        if adim == 0 {
            // seçilen ülke koduna göre uygulama dilini ayarla
            if let dil = LoginView.dilBul(tam) { yerel.secim = dil }
            if let e = await api.smsGonder(tam) { hata = e }
            else { adim = 1; bilgi = "Kod telefonuna gönderildi." }
        } else {
            if let e = await api.smsDogrula(tam, kod) { hata = e } else { dismiss() }
        }
    }

    // Telefon ülke kodu → uygulama dili
    static func dilBul(_ tel: String) -> String? {
        let d = tel.filter { $0.isNumber }
        let harita: [(String, String)] = [
            ("90","tr"),("49","de"),("43","de"),("41","de"),("33","fr"),("32","fr"),
            ("34","es"),("7","ru"),("380","ru"),
            ("971","ar"),("966","ar"),("20","ar"),("962","ar"),("965","ar"),("973","ar"),
            ("974","ar"),("968","ar"),("212","ar"),("213","ar"),("216","ar"),("961","ar"),
            ("1","en"),("44","en"),("353","en"),("61","en"),("64","en")
        ].sorted { $0.0.count > $1.0.count }   // uzun kod önce
        for (kod, dil) in harita where d.hasPrefix(kod) { return dil }
        return nil
    }
}
