//
//  RemoteDeckPresenter.swift
//  FlashcardApp
//
//  One deck of the account (the learner's own or a public one): its cards, and what can be done with it here.
//  Studying happens on the device, so "Study" first saves a copy (with the server's own ids, so saving again
//  finds the first copy). Archiving hides the learner's own deck on the server; a copy on the device stays.
//

import Foundation
import RxSwift

struct RemoteDeckState: Equatable {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
        case signInRequired
    }

    enum Busy: Equatable {
        case saving
        case archiving
    }

    var phase: Phase = .loading
    var title = ""
    var details = ""
    var visibility: ServerDeckVisibility = .private
    var isOwned = false
    var cards: [ServerDeckCard] = []
    var isOnDevice = false
    var busy: Busy?
    /// A save or archive that failed, shown beside the actions.
    var notice: String?

    var canStudy: Bool { phase == .loaded && !cards.isEmpty && busy == nil }
}

protocol RemoteDeckViewInterface: AnyObject {
    func render(_ state: RemoteDeckState)
}

protocol RemoteDeckPresenterInterface: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func retry()
    func signIn()
    func study()
    func saveToDevice()
    func archive()
}

final class RemoteDeckPresenter {
    private let deckId: String
    private let interactor: CardLibraryServerInteractorInterface
    private let wireframe: RemoteDeckWireframeInterface
    weak var view: RemoteDeckViewInterface?

    private var state = RemoteDeckState()
    private var detail: ServerDeckDetail?
    private let request = SerialDisposable()

    init(deckId: String, interactor: CardLibraryServerInteractorInterface, wireframe: RemoteDeckWireframeInterface) {
        self.deckId = deckId
        self.interactor = interactor
        self.wireframe = wireframe
    }

    deinit { request.dispose() }

    private func load() {
        guard interactor.isSignedIn else {
            state.phase = .signInRequired
            return publish()
        }
        state.phase = .loading
        publish()
        request.disposable = interactor.detail(deckId: deckId)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] detail in
                guard let self else { return }
                self.detail = detail
                self.state.phase = .loaded
                self.state.title = detail.deck.title
                self.state.details = detail.deck.details
                self.state.visibility = detail.deck.visibility
                self.state.isOwned = detail.deck.isOwned
                self.state.cards = detail.cards
                self.state.isOnDevice = self.interactor.hasDeviceCopy(deckId: detail.deck.id)
                self.publish()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                if case LearnerAPIError.signInRequired = error { self.state.phase = .signInRequired } else {
                    self.state.phase = .failed(CardPresenter.message(for: error))
                }
                self.publish()
            })
    }

    private func publish() { view?.render(state) }

    /// Saves the copy on the device when there is none. Returns whether a copy exists afterwards.
    private func ensureDeviceCopy() -> Bool {
        guard let detail else { return false }
        do {
            _ = try interactor.saveToDevice(detail)
            state.isOnDevice = true
            return true
        } catch {
            state.notice = CardPresenter.message(for: error)
            return false
        }
    }
}

extension RemoteDeckPresenter: RemoteDeckPresenterInterface {
    func viewDidLoad() { load() }

    func viewWillAppear() {
        // Returning from studying or editing: the copy may have been deleted from the library since.
        guard let detail, state.busy == nil else { return }
        let onDevice = interactor.hasDeviceCopy(deckId: detail.deck.id)
        if onDevice != state.isOnDevice {
            state.isOnDevice = onDevice
            publish()
        }
    }

    func retry() { load() }

    func signIn() {
        wireframe.showSignIn { [weak self] in self?.load() }
    }

    func study() {
        guard state.canStudy, let detail else { return }
        state.notice = nil
        guard ensureDeviceCopy() else { return publish() }
        publish()
        wireframe.showStudy(deckId: detail.deck.id)
    }

    func saveToDevice() {
        guard state.phase == .loaded, state.busy == nil, !state.isOnDevice else { return }
        state.notice = nil
        state.busy = .saving
        publish()
        _ = ensureDeviceCopy()
        state.busy = nil
        publish()
    }

    func archive() {
        guard state.phase == .loaded, state.isOwned, state.busy == nil else { return }
        let name = state.title
        wireframe.confirmArchive(deckName: name) { [weak self] in
            guard let self, self.state.busy == nil else { return }
            self.state.busy = .archiving
            self.state.notice = nil
            self.publish()
            self.request.disposable = self.interactor.archive(deckId: self.deckId)
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] in
                    guard let self else { return }
                    self.state.busy = nil
                    self.wireframe.leave()
                }, onFailure: { [weak self] error in
                    guard let self else { return }
                    self.state.busy = nil
                    self.state.notice = CardPresenter.message(for: error)
                    self.publish()
                })
        }
    }
}
