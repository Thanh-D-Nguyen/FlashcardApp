//
//  StartUpPresenter.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//
import Foundation
import RxRelay

protocol StartUpPresenterInterface: AnyObject {
    var progressTextRelay: PublishRelay<String> { get }
    func viewWillApprear()
}

final class StartUpPresenter {
    
    private let interactor: StartUpInteractorInterface
    private let wireframe: StartUpWireframeInterface
    
    let progressTextRelay = PublishRelay<String>()

    init(interactor: StartUpInteractorInterface,
         wireframe: StartUpWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

// MARK: - Extensions -
extension StartUpPresenter: StartUpPresenterInterface {
    func viewWillApprear() {
        RealmService.shared.configuration()
        RealmService.shared.copyProgress = { [weak self] progress in
            guard let self else { return }
            let progressTextFormat = NSLocalizedString("Preparing Data...", comment: "")
            let progressFomated = String(format: "%.1f", progress)
            let progressText = String(format: progressTextFormat, "\(progressFomated)/100.0")
            self.progressTextRelay.accept(progressText)
            if progress >= 100.0 {
                self.wireframe.navigateToWelcomeSlideShow()
            }
        }
    }
}
