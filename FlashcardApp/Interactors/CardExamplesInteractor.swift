//
//  CardExamplesInteractor.swift
//  FlashcardApp
//
//  Looks example sentences up for a card's Japanese word through the public sentence search. Answers are kept in
//  memory for the session so flipping back and forth, or revisiting a card, does not ask the server again.
//  Cancelling the subscription cancels the request. Nothing is saved on the card.
//

import Foundation
import RxSwift

protocol CardExamplesInteractorInterface: AnyObject {
    func examples(for term: String, cardReading: String) -> Single<[CardExample]>
}

protocol SentenceSearchInterface: AnyObject {
    func sentences(containing text: String, limit: Int) -> Single<[BJTSearchResultDTO]>
}

extension BJTSearchAPI: SentenceSearchInterface {
    func sentences(containing text: String, limit: Int) -> Single<[BJTSearchResultDTO]> {
        search(q: text, scope: .sentence, limit: limit)
    }
}

final class CardExamplesInteractor: CardExamplesInteractorInterface {
    static let cacheCapacity = 60

    private let search: SentenceSearchInterface
    /// Main thread only: lookups are started and delivered there.
    private var cache: [String: [CardExample]] = [:]
    private var cacheOrder: [String] = []

    init(search: SentenceSearchInterface = BJTSearchAPI.shared) {
        self.search = search
    }

    func examples(for term: String, cardReading: String) -> Single<[CardExample]> {
        let key = "\(term)|\(cardReading)"
        if let cached = cache[key] { return .just(cached) }
        return search.sentences(containing: term, limit: CardExampleLookup.candidateLimit)
            .map { CardExampleLookup.examples(from: $0, term: term, cardReading: cardReading) }
            .observe(on: MainScheduler.instance)
            .do(onSuccess: { [weak self] in self?.remember($0, for: key) })
    }

    private func remember(_ examples: [CardExample], for key: String) {
        if cache.updateValue(examples, forKey: key) == nil { cacheOrder.append(key) }
        while cacheOrder.count > Self.cacheCapacity { cache[cacheOrder.removeFirst()] = nil }
    }
}
