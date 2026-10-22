//
//  StartUpViewController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit

/// Hand-off between the system launch screen and the app. It is drawn in the launch-screen color and
/// stays empty unless preparing the offline data is slow or fails, so a normal launch has no extra screen.
final class StartUpViewController: BaseViewController {
    var presenter: StartUpPresenterInterface!

    private let stateView = StateView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }

    func setupUI() {
        view.backgroundColor = Design.Color.background
        stateView.isHidden = true
        stateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func subscribe() {
        subscribe(presenter.stateRelay) { [weak self] state in
            self?.render(state)
        }
    }

    private func render(_ state: StartUpState) {
        switch state {
        case .preparing:
            stateView.isHidden = true
        case .slow:
            reveal(animated: true)
            stateView.configure(.loading(NSLocalizedString("Preparing your offline lessons…", comment: "Start-up loading text on first launch while the bundled lessons are installed")))
        case .failed(let message):
            reveal(animated: false)
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Retry", comment: "")),
                                onRetry: { [weak self] in self?.presenter.retry() })
        }
    }

    /// The loading state fades in; Reduce Motion and error states appear at once.
    private func reveal(animated: Bool) {
        guard stateView.isHidden else { return }
        stateView.isHidden = false
        guard animated, !UIAccessibility.isReduceMotionEnabled else { return }
        stateView.alpha = 0
        UIView.animate(withDuration: 0.25) { self.stateView.alpha = 1 }
    }
}
