//
//  DictionarySavedInteractor.swift
//  FlashcardApp
//
//  The account's bookmarks as dictionary entries. The server's list has only ids, so each id is resolved to its entry
//  through the public detail endpoints, a page at a time. An entry the dictionary no longer has (404) is skipped and
//  counted; any other failure fails the page, so a flaky connection never looks like "you saved fewer words".
//

import Foundation
import RxSwift

struct SavedPage: Equatable {
    let items: [DictionaryItem]
    /// Ids on this page the dictionary no longer holds.
    let missing: Int
}

protocol DictionarySavedInteractorInterface: AnyObject {
    var isSignedIn: Bool { get }
    /// Bookmark target ids of one kind, newest first (at most 100: the server's cap).
    func savedIDs(_ kind: DictionaryItemKind) -> Single<[String]>
    func resolve(_ ids: [String], kind: DictionaryItemKind) -> Single<SavedPage>
    /// Removes a bookmark. It reads the current state first, because the server's call is a toggle and would otherwise re-add
    /// an entry that was already removed somewhere else.
    func remove(_ item: DictionaryItem) -> Single<Void>
}

final class DictionarySavedInteractor: DictionarySavedInteractorInterface {
    static let resolveConcurrency = 4

    private let bookmarks: BJTBookmarkAPIInterface
    private let api: BJTDictionaryAPIInterface
    private let signedIn: () -> Bool

    init(bookmarks: BJTBookmarkAPIInterface = BJTBookmarkAPI.shared, api: BJTDictionaryAPIInterface = BJTDictionaryAPI.shared,
         signedIn: @escaping () -> Bool = { AuthSession.shared.bearerToken != nil }) {
        self.bookmarks = bookmarks
        self.api = api
        self.signedIn = signedIn
    }

    var isSignedIn: Bool { signedIn() }

    func savedIDs(_ kind: DictionaryItemKind) -> Single<[String]> {
        bookmarks.list(kind, limit: BJTBookmarkAPI.maximumLimit).map { rows in
            var seen = Set<String>()
            return rows.map(\.targetId).filter { seen.insert($0).inserted }
        }
    }

    func resolve(_ ids: [String], kind: DictionaryItemKind) -> Single<SavedPage> {
        guard !ids.isEmpty else { return .just(SavedPage(items: [], missing: 0)) }
        let lookups: [Observable<(Int, DictionaryItem?)>] = ids.enumerated().map { index, id in
            entry(kind: kind, id: id).asObservable()
                .map { (index, Optional($0)) as (Int, DictionaryItem?) }
                .catch { error in
                    // A bookmark whose entry was removed from the dictionary is skipped; anything else is a real failure.
                    if case LearnerAPIError.notFound = error { return .just((index, nil)) }
                    return .error(error)
                }
        }
        return Observable.from(lookups)
            .merge(maxConcurrent: Self.resolveConcurrency)
            .toArray()
            .map { (rows: [(Int, DictionaryItem?)]) -> SavedPage in
                let ordered = rows.sorted { $0.0 < $1.0 }
                return SavedPage(items: ordered.compactMap { $0.1 }, missing: ordered.filter { $0.1 == nil }.count)
            }
    }

    private func entry(kind: DictionaryItemKind, id: String) -> Single<DictionaryItem> {
        switch kind {
        case .vocabulary: return api.lexeme(id: id).map { DictionaryEntryMapper.vocabulary($0).item }
        case .kanji: return api.kanji(id: id).map { DictionaryEntryMapper.kanji($0).item }
        case .grammar: return api.grammar(id: id).map { DictionaryEntryMapper.grammar($0).item }
        case .sentence: return .error(LearnerAPIError.invalidRequest(nil))
        }
    }

    func remove(_ item: DictionaryItem) -> Single<Void> {
        bookmarks.check(item.kind, id: item.id).flatMap { [bookmarks] isBookmarked in
            guard isBookmarked else { return .just(()) }
            return bookmarks.toggle(item.kind, id: item.id).map { _ in () }
        }
    }
}
