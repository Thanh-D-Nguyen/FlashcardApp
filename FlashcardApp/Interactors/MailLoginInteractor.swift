//
//  MailLoginInteractor.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//

import RxSwift

protocol MailLoginInteractorInterface: AnyObject {
    func login(email: String, password: String) -> Single<SocialUserEntity>
}

final class MailLoginInteractor: MailLoginInteractorInterface {
    private let session: AuthSession

    init(session: AuthSession = .shared) {
        self.session = session
    }

    func login(email: String, password: String) -> Single<SocialUserEntity> {
        session.login(email: email, password: password)
    }
}
