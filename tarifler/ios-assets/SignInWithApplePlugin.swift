import Foundation
import Capacitor
import AuthenticationServices
import UIKit

@objc(SignInWithApplePlugin)
public class SignInWithApplePlugin: CAPPlugin, CAPBridgedPlugin, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    // Capacitor 6 ZORUNLU: bu protokol + alanlar olmadan plugin Plugins'e KAYITLANMAZ
    // (window.Capacitor.Plugins.SignInWithApple tanımsız kalır → fallback alert → 2.1.0 red)
    public let identifier = "SignInWithApplePlugin"
    public let jsName = "SignInWithApple"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "authorize", returnType: CAPPluginReturnPromise)
    ]

    private var pendingCall: CAPPluginCall?

    @objc func authorize(_ call: CAPPluginCall) {
        self.pendingCall = call
        DispatchQueue.main.async {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // iPad dahil tüm cihazlarda geçerli, sahneye bağlı bir pencere döndür.
    // Kopuk/boş UIWindow() iPad'de sunum hatasına yol açıyordu (Guideline 2.1a).
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 1) Plugin'in kendi view controller'ının penceresi
        if let w = self.bridge?.viewController?.view.window {
            return w
        }
        // 2) Öne çıkan (foreground) sahnenin key/ilk penceresi
        let scenes = UIApplication.shared.connectedScenes
        for case let ws as UIWindowScene in scenes where ws.activationState == .foregroundActive {
            if let kw = ws.windows.first(where: { $0.isKeyWindow }) ?? ws.windows.first {
                return kw
            }
        }
        // 3) Herhangi bir sahnedeki ilk pencere
        for case let ws as UIWindowScene in scenes {
            if let w = ws.windows.first { return w }
        }
        // 4) Son çare
        return UIWindow()
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            pendingCall?.reject("Invalid credential type")
            pendingCall = nil
            return
        }
        var result: [String: Any] = [
            "user": credential.user,
            "state": credential.state ?? ""
        ]
        if let identityToken = credential.identityToken,
           let tokenStr = String(data: identityToken, encoding: .utf8) {
            result["identityToken"] = tokenStr
        }
        if let authCode = credential.authorizationCode,
           let codeStr = String(data: authCode, encoding: .utf8) {
            result["authorizationCode"] = codeStr
        }
        if let email = credential.email {
            result["email"] = email
        }
        if let fullName = credential.fullName {
            var nameParts: [String] = []
            if let given = fullName.givenName { nameParts.append(given) }
            if let family = fullName.familyName { nameParts.append(family) }
            result["givenName"] = fullName.givenName ?? ""
            result["familyName"] = fullName.familyName ?? ""
            result["fullName"] = nameParts.joined(separator: " ")
        }
        pendingCall?.resolve(result)
        pendingCall = nil
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Kullanıcı iptali (1001) sessiz geçilsin; diğer hatalar koda iletilsin.
        let code = (error as? ASAuthorizationError)?.code
        if code == .canceled {
            pendingCall?.reject("canceled", "1001")
        } else {
            pendingCall?.reject(error.localizedDescription)
        }
        pendingCall = nil
    }
}
