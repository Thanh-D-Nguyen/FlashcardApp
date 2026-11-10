import Foundation
import GoogleSignIn
import RxSwift
import UIKit

enum GoogleSignInError: Error, LocalizedError, Equatable {
    /// The build has no usable OAuth client configuration (see `GoogleSignInConfiguration`).
    case notConfigured
    /// The user dismissed Google's account sheet. Not a failure to report.
    case cancelled
    /// Google returned no usable ID token, or one meant for a different audience than the server's web client.
    case invalidToken
    /// Any other SDK failure (network, keychain, interrupted flow).
    case failed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return NSLocalizedString("Google sign-in is not set up in this version of the app.", comment: "")
        case .cancelled:
            return NSLocalizedString("Sign-in was cancelled. Please try again.", comment: "")
        case .invalidToken, .failed:
            return NSLocalizedString("Google sign-in did not complete. Please try again.", comment: "")
        }
    }
}

/// The two OAuth clients Google sign-in needs, both read from Info.plist (filled in from the environment's xcconfig):
/// - `GIDClientID`: the **iOS** client for this bundle ID. Local and production bundle IDs need different clients.
/// - `GIDServerClientID`: the **Web** client the backend verifies. Google sets it as the ID token's `aud`.
/// Neither is a secret. A missing, malformed or swapped value disables the feature instead of failing at sign-in time.
struct GoogleSignInConfiguration: Equatable {
    let clientID: String
    let serverClientID: String

    private static let clientIDSuffix = ".apps.googleusercontent.com"
    private static let reversedSchemePrefix = "com.googleusercontent.apps."

    init?(clientID: String?, serverClientID: String?, urlSchemes: [String]) {
        guard let clientID, let serverClientID,
              Self.isClientID(clientID), Self.isClientID(serverClientID),
              clientID != serverClientID,
              // Google redirects back to the app through the reversed iOS client ID; without it the flow never returns.
              urlSchemes.contains(Self.reversedSchemePrefix + clientID.dropLast(Self.clientIDSuffix.count)) else { return nil }
        self.clientID = clientID
        self.serverClientID = serverClientID
    }

    init?(bundle: Bundle = .main) {
        let schemes = (bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? [])
            .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        self.init(clientID: bundle.object(forInfoDictionaryKey: "GIDClientID") as? String,
                  serverClientID: bundle.object(forInfoDictionaryKey: "GIDServerClientID") as? String,
                  urlSchemes: schemes)
    }

    private static func isClientID(_ value: String) -> Bool {
        value.range(of: #"^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$"#, options: .regularExpression) != nil
    }

    /// The `aud` claim of a compact JWT, read without verifying the signature. Only used to fail early with a precise
    /// error when the wrong client is configured; the server performs the real verification.
    static func audience(ofIDToken token: String) -> String? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return claims["aud"] as? String
    }
}

protocol GoogleIDTokenProviding: AnyObject {
    /// False when this build has no valid Google OAuth configuration; the sign-in button is then not shown.
    var isAvailable: Bool { get }
    /// A fresh Google ID token for the server's web client. Subscribe on the main thread.
    func idToken(presenting viewController: UIViewController) -> Single<String>
}

final class GoogleIDTokenProvider: GoogleIDTokenProviding {
    private let configuration: GoogleSignInConfiguration?

    init(configuration: GoogleSignInConfiguration? = GoogleSignInConfiguration()) {
        self.configuration = configuration
    }

    var isAvailable: Bool { configuration != nil }

    func idToken(presenting viewController: UIViewController) -> Single<String> {
        Single.create { [configuration] observer in
            guard let configuration else {
                observer(.failure(GoogleSignInError.notConfigured))
                return Disposables.create()
            }
            let signIn = GIDSignIn.sharedInstance
            signIn.configuration = GIDConfiguration(clientID: configuration.clientID, serverClientID: configuration.serverClientID)
            signIn.signIn(withPresenting: viewController) { result, error in
                // The ID token only proves identity to our server once. Do not leave a Google session in the Keychain.
                signIn.signOut()
                if let error {
                    let cancelled = (error as NSError).domain == kGIDSignInErrorDomain
                        && (error as NSError).code == GIDSignInError.canceled.rawValue
                    observer(.failure(cancelled ? GoogleSignInError.cancelled : GoogleSignInError.failed))
                } else if let token = result?.user.idToken?.tokenString, !token.isEmpty,
                          GoogleSignInConfiguration.audience(ofIDToken: token) == configuration.serverClientID {
                    observer(.success(token))
                } else {
                    observer(.failure(GoogleSignInError.invalidToken))
                }
            }
            // The SDK cannot abort a flow that is on screen; a disposed subscription simply ignores its late result.
            return Disposables.create()
        }
        .subscribe(on: MainScheduler.instance)
    }
}
