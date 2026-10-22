//
//  DeckGeneratorPresenter.swift
//  FlashcardApp
//
//  Configure → preview the available card count → generate → download → open in the editor.
//  Generation creates a deck on the server and cannot be repeated safely, so it runs at most once per tap and is
//  never retried automatically. The download that follows is a plain read and may be retried.
//

import Foundation
import RxRelay
import RxSwift

struct DeckGeneratorState: Equatable {
    enum Preview: Equatable {
        case signInRequired
        case loading
        case ready(available: Int)
        case failed(String)
    }

    enum Phase: Equatable {
        case editing
        case generating
        case downloading
    }

    var request: DeckGenerationRequest
    var preview: Preview = .loading
    var phase: Phase = .editing
    /// Why the last attempt did not finish; stays until the learner acts again.
    var notice: String?
    /// The server created this deck but its cards are not on the device yet: the primary action downloads them.
    var pendingDownload: GeneratedDeckReceipt?

    /// Cards the server can supply for the filters, capped by the requested count.
    var expectedCount: Int? {
        guard case .ready(let available) = preview else { return nil }
        return min(available, request.count)
    }

    static let minimumUsableCards = 2

    var canGenerate: Bool {
        guard phase == .editing else { return false }
        if pendingDownload != nil { return true }
        guard request.issues.isEmpty, case .ready(let available) = preview else { return false }
        return available >= Self.minimumUsableCards
    }

    var isBusy: Bool { phase != .editing }
}

protocol DeckGeneratorViewInterface: AnyObject {
    func render(_ state: DeckGeneratorState)
}

protocol DeckGeneratorWireframeInterface: AnyObject {
    /// Closes the generator and opens the imported deck in the editor.
    func showDeck(withId id: String)
    func showSignIn(onFinish: @escaping () -> Void)
    func close()
    func showAlert(with title: String?, message: String?)
}

protocol DeckGeneratorPresenterInterface: AnyObject {
    var state: DeckGeneratorState { get }
    func viewDidLoad()
    func setLevel(_ level: GenerationLevel)
    func toggle(_ type: GenerationContentType)
    func setDirection(_ direction: GenerationDirection)
    func setCount(_ count: Int)
    func setName(_ name: String)
    func retryPreview()
    func signIn()
    func generate()
    func close()
}

final class DeckGeneratorPresenter {
    weak var view: DeckGeneratorViewInterface?

    private let interactor: DeckGeneratorInteractorInterface
    private let wireframe: DeckGeneratorWireframeInterface
    private let scheduler: SchedulerType
    private let previewDelay: RxTimeInterval
    private let disposeBag = DisposeBag()
    private let previewTrigger = PublishRelay<Void>()
    private let work = SerialDisposable()
    private var nameWasEdited = false
    private(set) var state: DeckGeneratorState

    init(interactor: DeckGeneratorInteractorInterface, wireframe: DeckGeneratorWireframeInterface,
         previewDelay: RxTimeInterval = .milliseconds(300), scheduler: SchedulerType = MainScheduler.instance) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.previewDelay = previewDelay
        self.scheduler = scheduler
        var request = DeckGenerationRequest()
        request.name = DeckGenerationRequest.suggestedName(level: request.level, contentTypes: request.contentTypes)
        state = DeckGeneratorState(request: request)
    }

    deinit { work.dispose() }

    private func publish() { view?.render(state) }

    private func bindPreview() {
        // A newer choice cancels the count request still running for the previous one.
        previewTrigger
            .debounce(previewDelay, scheduler: scheduler)
            .map { [weak self] in self?.state.request }
            .flatMapLatest { [weak self] request -> Observable<(DeckGenerationRequest, DeckGeneratorState.Preview)> in
                guard let self, let request else { return .empty() }
                guard self.interactor.isSignedIn else { return .just((request, .signInRequired)) }
                return self.interactor.preview(level: request.level, contentTypes: request.contentTypes.sorted { $0.rawValue < $1.rawValue })
                    .map { (request, DeckGeneratorState.Preview.ready(available: $0)) }
                    .catch { .just((request, Self.previewState(for: $0))) }
                    .asObservable()
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] request, preview in
                guard let self else { return }
                // Ignore an answer for choices the learner has already changed.
                guard request.level == self.state.request.level, request.contentTypes == self.state.request.contentTypes else { return }
                self.state.preview = preview
                self.publish()
            })
            .disposed(by: disposeBag)
    }

    static func previewState(for error: Error) -> DeckGeneratorState.Preview {
        if case LearnerAPIError.signInRequired = error { return .signInRequired }
        return .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }

    private func requestPreview() {
        guard !state.isBusy else { return }
        state.preview = interactor.isSignedIn ? .loading : .signInRequired
        previewTrigger.accept(())
    }

    private func choicesChanged() {
        state.notice = nil
        if !nameWasEdited {
            state.request.name = DeckGenerationRequest.suggestedName(level: state.request.level, contentTypes: state.request.contentTypes)
        }
        requestPreview()
        publish()
    }

    // MARK: Generation

    private func startDownload(_ receipt: GeneratedDeckReceipt) {
        state.phase = .downloading
        state.pendingDownload = receipt
        state.notice = nil
        publish()
        work.disposable = interactor.download(receipt)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] deck in self?.finishImport(deck) },
                       onFailure: { [weak self] error in
                guard let self else { return }
                self.state.phase = .editing
                // The deck exists on the server: keep the receipt so the retry only repeats the read.
                self.state.notice = String(format: NSLocalizedString("The deck was created, but its cards could not be downloaded: %@", comment: ""),
                                           (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                self.publish()
            })
    }

    private func finishImport(_ deck: GeneratedDeck) {
        do {
            let outcome = try interactor.importDeck(deck)
            state.pendingDownload = nil
            wireframe.showDeck(withId: outcome.deckId)
        } catch {
            state.phase = .editing
            state.notice = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            publish()
        }
    }

    static func notice(forGenerationError error: Error) -> String {
        let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        switch error {
        case LearnerAPIError.interrupted, LearnerAPIError.staleSession, LearnerAPIError.serviceUnavailable, LearnerAPIError.invalidResponse:
            // The request may have reached the server (and been committed) before the answer was lost or discarded.
            return description + " " + possibleDuplicateWarning
        case LearnerAPIError.server(let status) where status >= 500:
            return description + " " + possibleDuplicateWarning
        case LearnerAPIError.offline:
            return description + " " + NSLocalizedString("Nothing was created.", comment: "")
        default:
            return description
        }
    }

    private static var possibleDuplicateWarning: String {
        NSLocalizedString("The deck may already have been created in your account on the website. Check there before generating again, or you may get a second copy.", comment: "")
    }
}

extension DeckGeneratorPresenter: DeckGeneratorPresenterInterface {
    func viewDidLoad() {
        bindPreview()
        publish()
        requestPreview()
    }

    func setLevel(_ level: GenerationLevel) {
        guard !state.isBusy, state.request.level != level else { return }
        state.request.level = level
        choicesChanged()
    }

    func toggle(_ type: GenerationContentType) {
        guard !state.isBusy else { return }
        if state.request.contentTypes.contains(type) {
            // At least one kind of content stays selected.
            guard state.request.contentTypes.count > 1 else { return }
            state.request.contentTypes.remove(type)
        } else {
            state.request.contentTypes.insert(type)
        }
        choicesChanged()
    }

    func setDirection(_ direction: GenerationDirection) {
        guard !state.isBusy, state.request.direction != direction else { return }
        state.request.direction = direction
        state.notice = nil
        publish()
    }

    func setCount(_ count: Int) {
        guard !state.isBusy else { return }
        let step = DeckGenerationRequest.countStep
        let snapped = min(max((count + step / 2) / step * step, DeckGenerationRequest.countRange.lowerBound), DeckGenerationRequest.countRange.upperBound)
        guard state.request.count != snapped else { return }
        state.request.count = snapped
        state.notice = nil
        publish()
    }

    func setName(_ name: String) {
        guard !state.isBusy else { return }
        nameWasEdited = true
        state.request.name = name
        state.notice = nil
        // Not re-rendered: the text field already shows it, and rendering would move the caret.
    }

    func retryPreview() {
        requestPreview()
        publish()
    }

    func signIn() {
        wireframe.showSignIn { [weak self] in self?.retryPreview() }
    }

    func generate() {
        guard state.canGenerate else { return }
        // A deck the server already created is only downloaded, never generated a second time.
        if let receipt = state.pendingDownload { return startDownload(receipt) }
        let request = state.request
        state.phase = .generating
        state.notice = nil
        publish()
        work.disposable = interactor.generate(request)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] receipt in self?.startDownload(receipt) },
                       onFailure: { [weak self] error in
                guard let self else { return }
                self.state.phase = .editing
                if case LearnerAPIError.signInRequired = error { self.state.preview = .signInRequired }
                self.state.notice = Self.notice(forGenerationError: error)
                self.publish()
            })
    }

    func close() {
        // Closing mid-request would cancel a deck creation whose outcome is then unknown.
        guard !state.isBusy else { return }
        wireframe.close()
    }
}
