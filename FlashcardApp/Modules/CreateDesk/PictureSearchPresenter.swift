//
//  PictureSearchPresenter.swift
//  FlashcardApp
//
//  Finds pictures for a card through `POST /api/media/search-images` (account required). Nothing is saved
//  until the learner picks one; the caller then downloads and stores the chosen picture. The server may answer
//  503 while no image provider is configured, which is an expected state here, never a blocker for editing.
//

import Foundation
import RxSwift

enum PictureSearchState: Equatable {
    /// No search term yet.
    case needsTerm
    case signInRequired
    case loading
    case results([PictureSuggestion])
    case empty
    /// The server has no picture provider available (HTTP 503). Manual pictures still work.
    case unavailable
    case failed(String)
}

protocol PictureSearchViewInterface: AnyObject {
    func render(_ state: PictureSearchState)
}

protocol PictureSearchPresenterInterface: AnyObject {
    var initialTerm: String { get }
    func viewDidLoad()
    func search(_ term: String)
    func select(_ picture: PictureSuggestion)
    func signIn()
    func close()
}

final class PictureSearchPresenter {
    weak var view: PictureSearchViewInterface?

    private let interactor: PictureSearchInteractorInterface
    private let wireframe: PictureSearchWireframeInterface
    private let onPick: (PictureSuggestion) -> Void
    private let request = SerialDisposable()
    private var lastTerm: String
    private(set) var state: PictureSearchState = .needsTerm

    let initialTerm: String

    init(term: String, interactor: PictureSearchInteractorInterface, wireframe: PictureSearchWireframeInterface,
         onPick: @escaping (PictureSuggestion) -> Void) {
        initialTerm = term
        lastTerm = term
        self.interactor = interactor
        self.wireframe = wireframe
        self.onPick = onPick
    }

    deinit { request.dispose() }

    private func show(_ newState: PictureSearchState) {
        state = newState
        view?.render(newState)
    }

    static func message(for error: Error) -> PictureSearchState {
        switch error {
        case LearnerAPIError.signInRequired: return .signInRequired
        case LearnerAPIError.serviceUnavailable: return .unavailable
        case let error as LearnerAPIError: return .failed(error.errorDescription ?? error.localizedDescription)
        default: return .failed(error.localizedDescription)
        }
    }
}

extension PictureSearchPresenter: PictureSearchPresenterInterface {
    func viewDidLoad() {
        search(initialTerm)
    }

    func search(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        lastTerm = trimmed
        request.disposable = Disposables.create()
        guard trimmed.count >= 2 else { return show(.needsTerm) }
        guard interactor.isSignedIn else { return show(.signInRequired) }
        show(.loading)
        // A newer search replaces this one: assigning to the serial disposable cancels the request in flight.
        request.disposable = interactor.search(trimmed)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] pictures in
                self?.show(pictures.isEmpty ? .empty : .results(pictures))
            }, onFailure: { [weak self] error in
                self?.show(Self.message(for: error))
            })
    }

    func select(_ picture: PictureSuggestion) {
        request.disposable = Disposables.create()
        wireframe.close { [onPick] in onPick(picture) }
    }

    func signIn() {
        wireframe.showSignIn { [weak self] in
            guard let self else { return }
            self.search(self.lastTerm)
        }
    }

    func close() {
        request.disposable = Disposables.create()
        wireframe.close(then: nil)
    }
}
