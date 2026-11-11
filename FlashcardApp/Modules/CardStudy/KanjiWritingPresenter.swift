import Foundation
import RxSwift

/// One kanji to write: the card's word with that character hidden, and its reading and meaning as the cue.
struct KanjiWritingQuestion: Equatable {
    let cardID: String
    let target: String
    let maskedWord: String
    let reading: String
    let meaning: String
}

enum KanjiWritingQuestions {
    /// A CJK ideograph (kanji), not kana or Latin.
    static func isKanji(_ character: Character) -> Bool {
        character.unicodeScalars.count == 1 && character.unicodeScalars.allSatisfy {
            (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value)
        }
    }

    /// Every kanji of every card whose front is Japanese, once per card and character, in deck order. Words longer than six
    /// characters are left out: the cue would be too long to read while writing. A character the recognizer has no template for
    /// cannot be checked and is left out too.
    static func make(from cards: [StudyCard], canCheck: (String) -> Bool) -> [KanjiWritingQuestion] {
        cards.flatMap { card -> [KanjiWritingQuestion] in
            let word = card.front.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...6).contains(word.count), !card.back.isEmpty else { return [] }
            var seen = Set<Character>()
            return word.enumerated().compactMap { index, character in
                guard isKanji(character), seen.insert(character).inserted, canCheck(String(character)) else { return nil }
                let masked = String(word.enumerated().map { $0.offset == index ? "□" : $0.element })
                return KanjiWritingQuestion(cardID: card.id, target: String(character), maskedWord: masked, reading: card.reading, meaning: card.back)
            }
        }
    }

    /// The recognizer's best few guesses include the target. Five because similar kanji (未/末) can trade places for a hand-drawn shape.
    static let acceptedRank = 5

    static func isRight(target: String, candidates: [String]) -> Bool {
        candidates.prefix(acceptedRank).contains(target)
    }
}

struct KanjiWritingState: Equatable {
    enum Phase: Equatable {
        case empty
        case writing
        case checking
        case answered(correct: Bool)
        case finished
    }

    var phase: Phase = .writing
    var question: KanjiWritingQuestion?
    var position = 0
    var total = 0
    var correct = 0
    var hasInk = false
    var notice: String?
}

protocol KanjiWritingViewInterface: AnyObject {
    func render(_ state: KanjiWritingState)
    func clearCanvas()
}

protocol KanjiWritingPresenterInterface: AnyObject {
    func viewDidLoad()
    func inkChanged(_ ink: HandwritingInk)
    func check()
    func next()
    func clear()
}

/// Write each kanji of a deck from its reading and meaning; the app checks the drawing with the same stroke templates as the
/// dictionary's handwriting search. Practice only: nothing is written to the review history or the schedule.
final class KanjiWritingPresenter: KanjiWritingPresenterInterface {
    private let questions: [KanjiWritingQuestion]
    private let recognizer: HandwritingRecognizing
    private let request = SerialDisposable()
    weak var view: KanjiWritingViewInterface?

    private(set) var state = KanjiWritingState()
    private var ink = HandwritingInk()

    init(questions: [KanjiWritingQuestion], recognizer: HandwritingRecognizing) {
        self.questions = questions
        self.recognizer = recognizer
    }

    deinit { request.dispose() }

    private func publish() { view?.render(state) }

    func viewDidLoad() {
        state.total = questions.count
        state.phase = questions.isEmpty ? .empty : .writing
        state.question = questions.first
        publish()
    }

    func inkChanged(_ ink: HandwritingInk) {
        guard state.phase == .writing else { return }
        self.ink = ink
        state.hasInk = !ink.isEmpty
        state.notice = nil
        publish()
    }

    func clear() {
        guard state.phase == .writing else { return }
        ink = HandwritingInk()
        state.hasInk = false
        view?.clearCanvas()
        publish()
    }

    func check() {
        guard state.phase == .writing, state.hasInk, let question = state.question else { return }
        state.phase = .checking
        publish()
        request.disposable = recognizer.candidates(for: ink)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] candidates in
                guard let self, self.state.phase == .checking, self.state.question == question else { return }
                let right = KanjiWritingQuestions.isRight(target: question.target, candidates: candidates)
                if right { self.state.correct += 1 }
                self.state.phase = .answered(correct: right)
                self.publish()
            }, onFailure: { [weak self] error in
                guard let self, self.state.phase == .checking else { return }
                self.state.phase = .writing
                self.state.notice = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.publish()
            })
    }

    func next() {
        guard case .answered = state.phase else { return }
        ink = HandwritingInk()
        state.hasInk = false
        state.notice = nil
        view?.clearCanvas()
        if state.position + 1 < questions.count {
            state.position += 1
            state.question = questions[state.position]
            state.phase = .writing
        } else {
            state.phase = .finished
            state.question = nil
        }
        publish()
    }
}
