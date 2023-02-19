//
//  StartUpPresenter.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import Foundation

protocol StartUpPresenterInterface: AnyObject {
    func viewDidLoad()
}

final class StartUpPresenter {
    
    private let interactor: StartUpInteractorInterface
    private let wireframe: StartUpWireframeInterface

    init(interactor: StartUpInteractorInterface,
         wireframe: StartUpWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

// MARK: - Extensions -
extension StartUpPresenter: StartUpPresenterInterface {
    func viewDidLoad() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in
            guard let self else { return }
            self.wireframe.navigateToWelcomeSlideShow()
        })
    }
}
