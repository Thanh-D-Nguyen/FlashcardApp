//
//  DictionaryHistoryStore.swift
//  FlashcardApp
//
//  What the learner looked up on this device: recent queries and recently opened entries. It is NOT the account's
//  bookmark list (that lives on the server) and holds no dictionary content beyond the few text fields a history row
//  shows. Both lists are small and bounded, kept newest first, and can be cleared item by item or all at once.
//

import Foundation

protocol DictionaryHistoryStoreInterface: AnyObject {
    var recentQueries: [String] { get }
    var recentItems: [DictionaryItem] { get }
    func recordQuery(_ query: String)
    func removeQuery(_ query: String)
    func clearQueries()
    func recordItem(_ item: DictionaryItem)
    func removeItem(_ item: DictionaryItem)
    func clearItems()
}

final class UserDefaultsDictionaryHistoryStore: DictionaryHistoryStoreInterface {
    static let shared = UserDefaultsDictionaryHistoryStore()
    static let queryLimit = 20
    static let itemLimit = 30

    private let defaults: UserDefaults
    private let queryKey = "com.flashcardapp.dictionary.recentQueries"
    private let itemKey = "com.flashcardapp.dictionary.recentItems"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var recentQueries: [String] { defaults.stringArray(forKey: queryKey) ?? [] }

    var recentItems: [DictionaryItem] {
        guard let data = defaults.data(forKey: itemKey) else { return [] }
        // A list written by another version, or damaged, is dropped instead of crashing or blocking the screen.
        return (try? JSONDecoder().decode([DictionaryItem].self, from: data)) ?? []
    }

    func recordQuery(_ query: String) {
        guard case .valid(let valid) = DictionaryQuery.validate(query) else { return }
        var queries = recentQueries.filter { $0.caseInsensitiveCompare(valid.text) != .orderedSame }
        queries.insert(valid.text, at: 0)
        defaults.set(Array(queries.prefix(Self.queryLimit)), forKey: queryKey)
    }

    func removeQuery(_ query: String) {
        defaults.set(recentQueries.filter { $0 != query }, forKey: queryKey)
    }

    func clearQueries() { defaults.removeObject(forKey: queryKey) }

    func recordItem(_ item: DictionaryItem) {
        var items = recentItems.filter { !($0.kind == item.kind && $0.id == item.id) }
        items.insert(item, at: 0)
        store(Array(items.prefix(Self.itemLimit)))
    }

    func removeItem(_ item: DictionaryItem) {
        store(recentItems.filter { !($0.kind == item.kind && $0.id == item.id) })
    }

    func clearItems() { defaults.removeObject(forKey: itemKey) }

    private func store(_ items: [DictionaryItem]) {
        if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: itemKey) }
    }
}
