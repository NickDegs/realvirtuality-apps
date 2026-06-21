import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var yerel: Yerel
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var kod = ""
    @State private var adim = 0          // 0: e-posta, 1: kod
    @State private var hata = ""
    @State private var bekle = false

    var body: some View {
        ZStack {
            Color.rvBg.ignoresSafeArea()
            VStack(spacing: 18) {
                if api.girisli {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 54)).foregroundStyle(.rvViolet)
                    Text(api.email ?? "").font(.headline)
                    Text("⚡ \(api.kredi) kredi").foregroundStyle(.rvCyan)
                    Button(yerel.t("cikisYap")) { Task { await api.cikis(); dismiss() } }
                        .padding().frame(maxWidth: .infinity)
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))
                } else {
                    Text(yerel.t("girisBaslik")).font(.title2.bold())
                    Text(adim == 0 ? yerel.t("girisAlt") : yerel.t("kodIpucu"))
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

                    if adim == 0 {
                        TextField(yerel.t("epostaIpucu"), text: $email)
                            .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                            .padding().glassEffect(.regular, in: .rect(cornerRadius: 14))
                    } else {
                        TextField(yerel.t("kodIpucu"), text: $kod).keyboardType(.numberPad)
                            .multilineTextAlignment(.center).font(.title3)
                            .padding().glassEffect(.regular, in: .rect(cornerRadius: 14))
                    }

                    if !hata.isEmpty { Text(hata).font(.caption).foregroundStyle(.red) }

                    Button(adim == 0 ? yerel.t("kodGonder") : yerel.t("dogrula")) { Task { await ileri() } }
                        .font(.headline.bold()).foregroundStyle(.rvBg)
                        .frame(maxWidth: .infinity).padding()
                        .background(.linearGradient(colors: [.rvViolet, .rvCyan], startPoint: .leading, endPoint: .trailing))
                        .clipShape(.rect(cornerRadius: 14))
                        .opacity(bekle ? 0.6 : 1)

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
                    }

                    if adim == 1 {
                        Button("←") { adim = 0; kod = ""; hata = "" }
                            .font(.caption).foregroundStyle(.rvCyan)
                    }
                }
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }

    func ileri() async {
        hata = ""; bekle = true; defer { bekle = false }
        if adim == 0 {
            if let e = await api.kodGonder(email) { hata = e } else { adim = 1 }
        } else {
            if let e = await api.kodDogrula(email, kod) { hata = e } else { dismiss() }
        }
    }
}
