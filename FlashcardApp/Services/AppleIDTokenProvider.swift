import AuthenticationServices
import CryptoKit
import Foundation
import RxSwift
import Security
import UIKit

struct AppleIDTokenProof {
    let idToken: String
    let nonce: String
}

enum AppleSignInError: Error, LocalizedError, Equatable {
    case cancelled
    case invalidToken
    case failed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return NSLocalizedString("Sign-in was cancelled. Please try again.", comment: "")
        case .invalidToken, .failed:
            return NSLocalizedString("Apple sign-in did not complete. Please try again.", comment: "")
        }
    }
}

protocol AppleIDTokenProviding {
    func idToken(presenting viewController: UIViewController) -> Single<AppleIDTokenProof>
}

final class AppleIDTokenProvider: AppleIDTokenProviding {
    func idToken(presenting viewController: UIViewController) -> Single<AppleIDTokenProof> {
        Single.create { observer in
            guard let window = viewController.view.window else {
                observer(.failure(AppleSignInError.failed))
                return Disposables.create()
            }
            let flow = AppleAuthorizationFlow(window: window) { observer($0) }
            flow.start()
            return Disposables.create { flow.cancel() }
        }
        .subscribe(on: MainScheduler.instance)
    }
}

private final class AppleAuthorizationFlow: NSObject, ASAuthorizationControllerDelegate,
                                             ASAuthorizationControllerPresentationContextProviding {
    private let window: ASPresentationAnchor
    private var completion: ((SingleEvent<AppleIDTokenProof>) -> Void)?
    private var nonce: String?
    private var authorization: ASAuthorizationController?

    init(window: ASPresentationAnchor, completion: @escaping (SingleEvent<AppleIDTokenProof>) -> Void) {
        self.window = window
        self.completion = completion
    }

    func start() {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            finish(.failure(AppleSignInError.failed))
            return
        }
        let nonce = Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        self.nonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        authorization = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        window
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken,
              let idToken = String(data: data, encoding: .utf8),
              let nonce, !idToken.isEmpty else {
            finish(.failure(AppleSignInError.invalidToken))
            return
        }
        finish(.success(AppleIDTokenProof(idToken: idToken, nonce: nonce)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        finish(.failure(cancelled ? AppleSignInError.cancelled : AppleSignInError.failed))
    }

    private func finish(_ event: SingleEvent<AppleIDTokenProof>) {
        let callback = completion
        completion = nil
        nonce = nil
        authorization = nil
        callback?(event)
    }

    func cancel() {
        completion = nil
        nonce = nil
        authorization = nil
    }
}
