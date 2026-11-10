import Foundation
import RxRelay
import RxSwift

enum VoiceState: Equatable {
    /// Ready to listen, or explaining why it cannot.
    case ready(SpeechAccess)
    case listening(partial: String)
    /// Recognition ended; the text is shown for the learner to correct before searching.
    case result(String)
    case failed(String)
}

protocol DictionaryVoicePresenterInterface: AnyObject {
    var state: BehaviorRelay<VoiceState> { get }
    func viewWillAppear()
    /// Starts listening (asking permission first when needed), or stops listening and keeps what was heard.
    func toggleListening()
    func viewWillDisappear()
    func lookUp(_ text: String)
    func close()
    func openSettings()
}

final class DictionaryVoicePresenter: DictionaryVoicePresenterInterface {
    let state: BehaviorRelay<VoiceState>

    private let interactor: DictionaryVoiceInteractorInterface
    private let wireframe: DictionaryVoiceWireframeInterface
    private var listenBag = DisposeBag()
    private let permissionBag = DisposeBag()
    private var heard = ""
    private let stopRequests = PublishRelay<Void>()

    init(interactor: DictionaryVoiceInteractorInterface, wireframe: DictionaryVoiceWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
        state = BehaviorRelay(value: .ready(interactor.access))
    }

    func viewWillAppear() {
        if case .ready = state.value { state.accept(.ready(interactor.access)) }
    }

    func toggleListening() {
        if case .listening = state.value { return requestStop() }
        switch interactor.access {
        case .authorized:
            startListening()
        case .notDetermined:
            interactor.requestAccess()
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] access in
                    guard let self else { return }
                    if access == .authorized { self.startListening() } else { self.state.accept(.ready(access)) }
                })
                .disposed(by: permissionBag)
        case .denied, .unavailable:
            state.accept(.ready(interactor.access))
        }
    }

    private func startListening() {
        listenBag = DisposeBag()
        heard = ""
        state.accept(.listening(partial: ""))
        interactor.listen(stop: stopRequests.asObservable())
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] update in
                guard let self else { return }
                switch update {
                case .partial(let text):
                    self.heard = text
                    self.state.accept(.listening(partial: text))
                case .final(let text):
                    self.finish(with: text)
                }
            }, onError: { [weak self] error in
                guard let self else { return }
                // What was heard before the failure is not lost.
                if !self.heard.isEmpty { return self.finish(with: self.heard) }
                self.state.accept(.failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription))
            }, onCompleted: { [weak self] in
                guard let self, case .listening = self.state.value else { return }
                self.finish(with: self.heard)
            })
            .disposed(by: listenBag)
    }

    /// The learner tapped stop: the audio ends and the recognizer delivers what it still holds (the screen keeps showing
    /// "listening" for that moment); the final result, completion or the service's grace period then ends the session.
    private func requestStop() {
        stopRequests.accept(())
    }

    /// Leaving the screen: disposing the subscription releases the microphone at once.
    private func stopListening() {
        listenBag = DisposeBag()
        finish(with: heard)
    }

    private func finish(with text: String) {
        listenBag = DisposeBag()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        state.accept(trimmed.isEmpty ? .failed(NSLocalizedString("Nothing was heard. Try again, closer to the microphone.", comment: "")) : .result(trimmed))
    }

    func viewWillDisappear() {
        if case .listening = state.value { stopListening() }
    }

    func lookUp(_ text: String) {
        guard case .valid(let query) = DictionaryQuery.validate(text) else { return }
        wireframe.finish(lookingUp: query.text)
    }

    func close() {
        listenBag = DisposeBag()
        wireframe.close()
    }

    func openSettings() { wireframe.openSystemSettings() }
}
