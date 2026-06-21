import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var yerel: Yerel
    @Environment(\.dismiss) var dismiss
    @State private var mod = 0            // 0: e-posta, 1: SMS
    @State private var email = ""
    @State private var tel = ""
    @State private var kod = ""
    @State private var adim = 0          // 0: kimlik, 1: kod
    @State private var hata = ""
    @State private var bekle = false

    var body: some View {
        ZStack {
            Color.rvBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if api.girisli {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 54)).foregroundStyle(.rvViolet)
                        Text(api.email ?? api.tel ?? "").font(.headline)
                        Text("⚡ \(api.kredi) kredi").foregroundStyle(.rvCyan)
                        Text("Oturum iCloud ile cihazların arasında senkron.").font(.caption2).foregroundStyle(.secondary)
                        Button(yerel.t("cikisYap")) { Task { await api.cikis(); dismiss() } }
                            .padding().frame(maxWidth: .infinity)
                            .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    } else {
                        Text(yerel.t("girisBaslik")).font(.title2.bold())

                        if adim == 0 {
                            Picker("", selection: $mod) {
                                Text(yerel.p("girisEposta")).tag(0)
                                Text(yerel.p("girisSms")).tag(1)
                            }.pickerStyle(.segmented)
                        }

                        Text(adim == 0 ? (mod == 0 ? yerel.t("girisAlt") : yerel.p("telefon")) : yerel.t("kodIpucu"))
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

                        if adim == 0 {
                            if mod == 0 {
                                TextField(yerel.t("epostaIpucu"), text: $email)
                                    .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                                    .padding().glassEffect(.regular, in: .rect(cornerRadius: 14))
                            } else {
                                TextField(yerel.p("telefon"), text: $tel).keyboardType(.phonePad)
                                    .padding().glassEffect(.regular, in: .rect(cornerRadius: 14))
                            }
                        } else {
                            TextField(yerel.p("smsKodu"), text: $kod).keyboardType(.numberPad)
                                .multilineTextAlignment(.center).font(.title3)
                                .padding().glassEffect(.regular, in: .rect(cornerRadius: 14))
                        }

                        if !hata.isEmpty { Text(hata).font(.caption).foregroundStyle(.red) }

                        Button(adim == 0 ? yerel.p("kodGonder") : yerel.p("dogrulaGiris")) { Task { await ileri() } }
                            .font(.headline.bold()).foregroundStyle(.rvBg)
                            .frame(maxWidth: .infinity).padding()
                            .background(.linearGradient(colors: [.rvViolet, .rvCyan], startPoint: .leading, endPoint: .trailing))
                            .clipShape(.rect(cornerRadius: 14))
                            .opacity(bekle ? 0.6 : 1).disabled(bekle)

                        if adim == 0 {
                            HStack { Rectangle().fill(.white.opacity(0.12)).frame(height: 1); Text("•").font(.caption).foregroundStyle(.secondary); Rectangle().fill(.white.opacity(0.12)).frame(height: 1) }
                            SignInWithAppleButton(.signIn) { req in
                                req.requestedScopes = [.email, .fullName]
                            } onCompletion: { result in
                                if case .success(let auth) = result,
                                   let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                                   let td = cred.identityToken, let token = String(data: td, encoding: .utf8) {
                                    Task { if let e = await api.appleGiris(idToken: token, email: cred.email) { hata = e } else { dismiss() } }
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50).clipShape(.rect(cornerRadius: 14))
                        } else {
                            Button("←") { adim = 0; kod = ""; hata = "" }.font(.caption).foregroundStyle(.rvCyan)
                        }
                    }
                }
                .padding(24)
            }
        }
        .presentationDetents([.medium, .large])
    }

    func ileri() async {
        hata = ""; bekle = true; defer { bekle = false }
        if adim == 0 {
            let e = mod == 0 ? await api.kodGonder(email) : await api.smsGonder(tel)
            if let e = e { hata = e } else { adim = 1 }
        } else {
            let e = mod == 0 ? await api.kodDogrula(email, kod) : await api.smsDogrula(tel, kod)
            if let e = e { hata = e } else { dismiss() }
        }
    }
}
