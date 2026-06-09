import Foundation
import Capacitor
import AuthenticationServices

@objc(SignInWithApplePlugin)
public class SignInWithApplePlugin: CAPPlugin, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

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

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.bridge?.viewController?.view.window ?? UIWindow()
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            pendingCall?.reject("Invalid credential type")
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
        pendingCall?.reject(error.localizedDescription)
        pendingCall = nil
    }
}
