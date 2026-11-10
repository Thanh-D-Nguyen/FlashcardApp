//
//  MailLoginInteractor.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//

import RxSwift
import UIKit

protocol MailLoginInteractorInterface: AnyObject {
    func login(email: String, password: String) -> Single<SocialUserEntity>
    /// True when this build is configured for Google sign-in.
    var isGoogleSignInAvailable: Bool { get }
    func loginWithGoogle(presenting viewController: UIViewController) -> Single<SocialUserEntity>
    func loginWithApple(presenting viewController: UIViewController) -> Single<SocialUserEntity>
}

final class MailLoginInteractor: MailLoginInteractorInterface {
    private let session: AuthSession
    private let googleTokens: GoogleIDTokenProviding
    private let appleTokens: AppleIDTokenProviding

    init(session: AuthSession = .shared, googleTokens: GoogleIDTokenProviding = GoogleIDTokenProvider(),
         appleTokens: AppleIDTokenProviding = AppleIDTokenProvider()) {
        self.session = session
        self.googleTokens = googleTokens
        self.appleTokens = appleTokens
    }

    var isGoogleSignInAvailable: Bool { googleTokens.isAvailable }

    func login(email: String, password: String) -> Single<SocialUserEntity> {
        session.login(email: email, password: password)
    }

    /// Google proves who the user is; the website still issues the session. The Google token never leaves this chain.
    func loginWithGoogle(presenting viewController: UIViewController) -> Single<SocialUserEntity> {
        googleTokens.idToken(presenting: viewController)
            .flatMap { [session] idToken in session.loginWithGoogle(idToken: idToken) }
    }
    func loginWithApple(presenting viewController: UIViewController) -> Single<SocialUserEntity> {
        appleTokens.idToken(presenting: viewController)
            .flatMap { [session] proof in session.loginWithApple(idToken: proof.idToken, nonce: proof.nonce) }
    }

}
