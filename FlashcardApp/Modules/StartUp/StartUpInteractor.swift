//
//  StartUpInteractor.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import Foundation

protocol StartUpInteractorInterface: AnyObject {
    /// Installs the bundled offline database when needed and opens it. Both callbacks run on the main thread.
    func prepareDatabase(onComplete: @escaping () -> Void, onError: @escaping (AppError) -> Void)
}

final class StartUpInteractor {
    private let realmService: RealmService

    init(realmService: RealmService = .shared) {
        self.realmService = realmService
    }
}

extension StartUpInteractor: StartUpInteractorInterface {
    func prepareDatabase(onComplete: @escaping () -> Void, onError: @escaping (AppError) -> Void) {
        realmService.configuration(onComplete: onComplete, onError: onError)
    }
}
