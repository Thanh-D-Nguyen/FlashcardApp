//
//  PictureSearchPresenter.swift
//  FlashcardApp
//
//  Finds pictures for a card through `POST /api/media/search-images` (account required). Nothing is saved
//  until the learner picks one: the pick is first registered with `POST /api/media/image-selections` (the server
//  tells the picture provider, as its terms require), then the caller downloads and stores the picture. The server may answer
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
    /// True while the chosen picture is being registered with the server.
    func setSelecting(_ selecting: Bool)
    func showSelectionFailure(_ message: String)
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
    private let selection = SerialDisposable()
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

    deinit {
        request.dispose()
        selection.dispose()
    }

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
        view?.setSelecting(true)
        // Assigning replaces (and cancels) an earlier selection, so a double tap registers one choice.
        selection.disposable = interactor.select(picture)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] _ in
                guard let self else { return }
                self.view?.setSelecting(false)
                self.wireframe.close { [onPick = self.onPick] in onPick(picture) }
            }, onFailure: { [weak self] error in
                self?.view?.setSelecting(false)
                self?.view?.showSelectionFailure(Self.selectionMessage(for: error))
            })
    }

    static func selectionMessage(for error: Error) -> String {
        switch error {
        // The signed result is only valid for 15 minutes.
        case LearnerAPIError.invalidRequest: return NSLocalizedString("This result has expired. Search again and choose it once more.", comment: "")
        case let error as LearnerAPIError: return error.errorDescription ?? error.localizedDescription
        default: return error.localizedDescription
        }
    }

    func signIn() {
        wireframe.showSignIn { [weak self] in
            guard let self else { return }
            self.search(self.lastTerm)
        }
    }

    func close() {
        request.disposable = Disposables.create()
        selection.disposable = Disposables.create()
        wireframe.close(then: nil)
    }
}
