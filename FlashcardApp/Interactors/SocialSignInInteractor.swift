//
//  SocialSignInInteractor.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/13.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import FBSDKLoginKit
import AuthenticationServices
import CryptoKit

protocol SocialSignInInteractorInterface: AnyObject {
    var didLoginComplete: ((SocialUserEntity?, Error?) -> Void)? { get set }
    
    func signInWithFacebook()
    func signInWithGoogle()
    func signInWithApple()
}

class SocialSignInInteractor: NSObject {
    
    static let userDataKey = "SocialUserDataKey"
    
    private var currentNonce: String?
    
    var didLoginComplete: ((SocialUserEntity?, Error?) -> Void)?
    
    private func authWithCredential(_ credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { [unowned self] result, error in
            if let error = error {
                self.didLoginComplete?(nil, error)
                return
            }
            let user = SocialUserEntity(result?.user)
            self.didLoginComplete?(user, nil)
        }
    }

}

extension SocialSignInInteractor: SocialSignInInteractorInterface {
    func signInWithFacebook() {
        guard let tokenString = AccessToken.current?.tokenString else { return }
        let credential = FacebookAuthProvider.credential(withAccessToken: tokenString)
        self.authWithCredential(credential)
    }
    
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID,
        let mainView = Constants.mainView else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: mainView) { [unowned self] result, error in
            if let error = error {
                self.didLoginComplete?(nil, error)
                return
            }
            guard let idToken = result?.user.idToken?.tokenString,
                  let accessTkn = result?.user.accessToken.tokenString else { return }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessTkn)
            self.authWithCredential(credential)
        }
    }
        
    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
}

extension SocialSignInInteractor: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
            case let appleIDCredential as ASAuthorizationAppleIDCredential:
                guard let nonce = currentNonce else {
                    fatalError("Invalid state: A login callback was received, but no login request was sent.")
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    let error = NSError(domain: "Unable to fetch identity token", code: -1)
                    self.didLoginComplete?(nil, error)
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    let error = NSError(domain: "Unable to serialize token string from data: \(appleIDToken.debugDescription)", code: -1)
                    self.didLoginComplete?(nil, error)
                    return
                }
                // Initialize a Firebase credential.
                let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                          idToken: idTokenString,
                                                          rawNonce: nonce)
                authWithCredential(credential)
            default: break
        }
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        self.didLoginComplete?(nil, error)
    }
}

extension SocialSignInInteractor: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.delegate!.window!!
    }
}
/// Support Login security
extension SocialSignInInteractor {
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}
