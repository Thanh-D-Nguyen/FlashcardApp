import Foundation
import RxSwift

struct SharedDeckState: Equatable {
    enum Phase: Equatable {
        case loading
        case loaded
        /// The owner stopped sharing, or the link was never valid.
        case gone
        case failed(String)
    }

    var phase: Phase = .loading
    var title = ""
    var details = ""
    var samples: [String] = []
    var isSaving = false
    /// After an interrupted copy the outcome is unknown: saving again could make a second copy, so it is not offered.
    var canSave = false
    var saveTitle = ""
    var notice: String?
}

protocol SharedDeckViewInterface: AnyObject {
    func render(_ state: SharedDeckState)
}

protocol SharedDeckPresenterInterface: AnyObject {
    func viewDidLoad()
    func retry()
    func save()
}

protocol SharedDeckWireframeInterface: AnyObject {
    func showSignIn(onFinish: @escaping () -> Void)
    /// The copy in the account, in place of this preview.
    func showAccountDeck(id: String)
}

/// A deck someone shared by link: the public preview (anyone), and one "save to my account" that copies it (signed in).
final class SharedDeckPresenter: SharedDeckPresenterInterface {
    private let link: DeckShareLink
    private let interactor: DeckSharingInteractorInterface
    private let wireframe: SharedDeckWireframeInterface
    private let previewRequest = SerialDisposable()
    private let copyRequest = SerialDisposable()
    weak var view: SharedDeckViewInterface?

    private(set) var state = SharedDeckState()
    private var copyOutcomeUnknown = false

    init(link: DeckShareLink, interactor: DeckSharingInteractorInterface, wireframe: SharedDeckWireframeInterface) {
        self.link = link
        self.interactor = interactor
        self.wireframe = wireframe
    }

    deinit {
        previewRequest.dispose()
        copyRequest.dispose()
    }

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private func publish() {
        state.canSave = state.phase == .loaded && !state.isSaving && !copyOutcomeUnknown
        state.saveTitle = interactor.isSignedIn ? Self.text("Save to my account") : Self.text("Sign in to save")
        view?.render(state)
    }

    func viewDidLoad() { load() }

    func retry() { load() }

    private func load() {
        state.phase = .loading
        publish()
        previewRequest.disposable = interactor.preview(link)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] preview in
                guard let self else { return }
                let title = (AppLanguage.current == .japanese ? preview.titleJa?.trimmingCharacters(in: .whitespacesAndNewlines) : nil)
                    .flatMap { $0.isEmpty ? nil : $0 } ?? preview.titleVi
                self.state.phase = .loaded
                self.state.title = title
                self.state.details = String.localizedStringWithFormat(Self.text("%lld cards"), max(preview.cardCount, 0))
                self.state.samples = preview.sampleCards.map { sample in
                    guard let reading = sample.reading?.trimmingCharacters(in: .whitespacesAndNewlines), !reading.isEmpty, reading != sample.frontText else {
                        return sample.frontText
                    }
                    return "\(sample.frontText)（\(reading)）"
                }
                self.publish()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                if case LearnerAPIError.notFound = error {
                    self.state.phase = .gone
                } else {
                    self.state.phase = .failed(CardPresenter.message(for: error))
                }
                self.publish()
            })
    }

    func save() {
        guard state.canSave else { return }
        guard interactor.isSignedIn else {
            return wireframe.showSignIn { [weak self] in self?.publish() }
        }
        state.isSaving = true
        state.notice = nil
        publish()
        copyRequest.disposable = interactor.copyToAccount(link)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] id in
                guard let self else { return }
                self.state.isSaving = false
                self.publish()
                self.wireframe.showAccountDeck(id: id)
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.state.isSaving = false
                switch error as? LearnerAPIError {
                case .interrupted?:
                    self.copyOutcomeUnknown = true
                    self.state.notice = Self.text("We couldn't confirm the copy. Check your decks on the account before saving it again.")
                case .notFound?:
                    self.state.phase = .gone
                default:
                    self.state.notice = CardPresenter.message(for: error)
                }
                self.publish()
            })
    }
}
