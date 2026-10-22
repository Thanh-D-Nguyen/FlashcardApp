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
import RxSwift

/// What the start-up screen has to show while the offline database is prepared.
enum StartUpState: Equatable {
    /// Work is pending but fast enough that nothing is drawn; the screen stays the launch-screen color.
    case preparing
    /// Work is taking noticeable time (first install copies the bundled database).
    case slow
    /// Preparation failed; the message is shown with a retry action.
    case failed(String)
}

protocol StartUpPresenterInterface: AnyObject {
    var stateRelay: BehaviorRelay<StartUpState> { get }
    func viewWillAppear()
    func retry()
}

final class StartUpPresenter {

    private let interactor: StartUpInteractorInterface
    private let wireframe: StartUpWireframeInterface
    private let loadingGraceDelay: DispatchTimeInterval
    private let scheduler: SchedulerType
    private let graceTimer = SerialDisposable()
    private var isPreparing = false
    private var isFinished = false

    let stateRelay = BehaviorRelay<StartUpState>(value: .preparing)

    /// `loadingGraceDelay` is how long preparation may run before a loading state is drawn. It never
    /// postpones navigation: the hand-off happens the moment the database is ready.
    init(interactor: StartUpInteractorInterface,
         wireframe: StartUpWireframeInterface,
         loadingGraceDelay: DispatchTimeInterval = .milliseconds(400),
         scheduler: SchedulerType = MainScheduler.instance) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.loadingGraceDelay = loadingGraceDelay
        self.scheduler = scheduler
    }

    private func prepare(showsLoadingImmediately: Bool) {
        guard !isPreparing, !isFinished else { return }
        isPreparing = true
        if showsLoadingImmediately {
            stateRelay.accept(.slow)
        } else {
            stateRelay.accept(.preparing)
            graceTimer.disposable = Observable<Int>.timer(loadingGraceDelay, scheduler: scheduler)
                .subscribe(onNext: { [weak self] _ in
                    guard let self, self.isPreparing else { return }
                    self.stateRelay.accept(.slow)
                })
        }
        interactor.prepareDatabase(onComplete: { [weak self] in
            self?.finishPreparation()
        }, onError: { [weak self] error in
            self?.failPreparation(error)
        })
    }

    private func finishPreparation() {
        guard isPreparing else { return }
        isPreparing = false
        isFinished = true
        graceTimer.disposable = Disposables.create()
        // Cross-fade only away from a visible loading state; otherwise the cut is invisible.
        wireframe.navigateToMain(animated: stateRelay.value == .slow)
    }

    private func failPreparation(_ error: AppError) {
        guard isPreparing else { return }
        isPreparing = false
        graceTimer.disposable = Disposables.create()
        logger.error("Database initialization failed: \(error.localizedDescription)")
        stateRelay.accept(.failed(Self.message(for: error)))
    }

    /// The full-screen state already says what failed, so show the specific, localized reason without the generic prefix.
    private static func message(for error: AppError) -> String {
        if case .databaseInitializationFailed(let reason) = error { return reason }
        return error.errorDescription ?? NSLocalizedString("Error", comment: "")
    }
}

extension StartUpPresenter: StartUpPresenterInterface {
    func viewWillAppear() {
        prepare(showsLoadingImmediately: false)
    }

    func retry() {
        prepare(showsLoadingImmediately: true)
    }
}
