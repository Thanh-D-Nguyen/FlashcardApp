import Foundation
import RxRelay
import RxSwift

struct HandwritingState: Equatable {
    enum Recognition: Equatable {
        case idle
        case recognizing
        /// The strokes were read but no known character is close enough.
        case noMatch
        case failed(String)
    }

    /// Characters the learner has picked so far; this is what gets looked up.
    var text = ""
    /// Characters that look like the current strokes, best first.
    var candidates: [String] = []
    var recognition: Recognition = .idle
}

protocol DictionaryHandwritingPresenterInterface: AnyObject {
    var state: BehaviorRelay<HandwritingState> { get }
    /// Fires after a candidate is picked: the canvas is ready for the next character.
    var canvasShouldClear: PublishRelay<Void> { get }
    /// The strokes on the canvas changed (empty ink means the canvas is blank).
    func inkChanged(_ ink: HandwritingInk)
    func choose(_ candidate: String)
    func deleteLastCharacter()
    func lookUp()
    func close()
}

final class DictionaryHandwritingPresenter: DictionaryHandwritingPresenterInterface {
    /// A search keyword is at most this many characters here, far below the server's byte limit.
    static let maximumCharacters = 20

    let state = BehaviorRelay(value: HandwritingState())
    let canvasShouldClear = PublishRelay<Void>()

    private let interactor: DictionaryHandwritingInteractorInterface
    private let wireframe: DictionaryHandwritingWireframeInterface
    private let inkRequests = PublishRelay<HandwritingInk>()
    private let bag = DisposeBag()

    init(interactor: DictionaryHandwritingInteractorInterface, wireframe: DictionaryHandwritingWireframeInterface,
         debounce: RxTimeInterval = .milliseconds(350)) {
        self.interactor = interactor
        self.wireframe = wireframe
        inkRequests
            .flatMapLatest { ink -> Observable<(recognition: HandwritingState.Recognition, candidates: [String])> in
                guard !ink.isEmpty else { return .just((.idle, [])) }
                // The delay lives inside the latest request, so a stroke added while waiting or reading replaces it.
                return Observable<Int>.timer(debounce, scheduler: MainScheduler.instance)
                    .flatMap { _ in interactor.candidates(for: ink).asObservable() }
                    .map { $0.isEmpty ? (.noMatch, []) : (.idle, $0) }
                    .catch { .just((.failed(Self.message(for: $0)), [])) }
                    .startWith((.recognizing, []))
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] result in
                guard let self else { return }
                var current = self.state.value
                current.recognition = result.recognition
                // Candidates stay on screen while the next reading runs, so the strip does not flash empty between strokes.
                if result.recognition != .recognizing { current.candidates = result.candidates }
                self.state.accept(current)
            })
            .disposed(by: bag)
    }

    func inkChanged(_ ink: HandwritingInk) { inkRequests.accept(ink) }

    func choose(_ candidate: String) {
        var current = state.value
        guard current.candidates.contains(candidate), current.text.count + candidate.count <= Self.maximumCharacters else { return }
        current.text += candidate
        current.candidates = []
        current.recognition = .idle
        state.accept(current)
        // A reading still in flight belongs to strokes that are now part of the text.
        inkRequests.accept(HandwritingInk())
        canvasShouldClear.accept(())
    }

    func deleteLastCharacter() {
        var current = state.value
        guard !current.text.isEmpty else { return }
        current.text.removeLast()
        state.accept(current)
    }

    func lookUp() {
        guard case .valid(let query) = DictionaryQuery.validate(state.value.text) else { return }
        wireframe.finish(lookingUp: query.text)
    }

    func close() { wireframe.close() }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
