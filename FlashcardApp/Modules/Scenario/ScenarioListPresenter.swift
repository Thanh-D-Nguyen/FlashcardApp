//
//  ScenarioListPresenter.swift
//  FlashcardApp
//
//  The catalogue of everyday situations ("what do I say at the hairdresser's, at the hospital, at the ward office"), grouped the way
//  the website groups them. The learner can search, or narrow it to one group. Everything comes from the server: the app invents no
//  situation and keeps none.
//

import Foundation
import RxSwift

struct ScenarioRowState: Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let meta: String
}

struct ScenarioSectionState: Equatable {
    let key: String
    let title: String
    let symbol: String
    let rows: [ScenarioRowState]
}

struct ScenarioChipState: Equatable {
    let key: String
    let title: String
    let symbol: String
    let isSelected: Bool
}

struct ScenarioListState: Equatable {
    enum Screen: Equatable {
        case loading
        case signInRequired
        case failed(message: String, canRetry: Bool)
        case empty
        case noMatches(query: String)
        case content
    }

    var screen: Screen = .loading
    var chips: [ScenarioChipState] = []
    var sections: [ScenarioSectionState] = []
    /// "106 situations": the whole catalogue, whatever the search shows.
    var totalText = ""
}

protocol ScenarioListViewInterface: AnyObject {
    func render(_ state: ScenarioListState)
}

protocol ScenarioListPresenterInterface: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func retry()
    func signIn()
    func search(_ query: String)
    /// A group chip: narrows the list to that group; the selected one again shows everything.
    func toggleCategory(_ key: String)
    func select(id: String)
}

final class ScenarioListPresenter {
    private let interactor: ScenarioInteractorInterface
    private let wireframe: ScenarioListWireframeInterface
    weak var view: ScenarioListViewInterface?

    private var catalogue: [ScenarioSummary] = []
    private var query = ""
    private var category: String?
    private var screen: ScenarioListState.Screen = .loading
    private var loaded = false
    private let request = SerialDisposable()

    init(interactor: ScenarioInteractorInterface, wireframe: ScenarioListWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    deinit { request.dispose() }

    // MARK: Loading

    private func load() {
        guard interactor.isSignedIn else {
            loaded = false
            screen = .signInRequired
            return publish()
        }
        screen = .loading
        publish()
        request.disposable = interactor.catalogue()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] list in
                guard let self else { return }
                self.catalogue = list
                self.loaded = true
                self.screen = list.isEmpty ? .empty : .content
                self.publish()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.loaded = false
                if case LearnerAPIError.staleSession = error { return }
                if case LearnerAPIError.signInRequired = error {
                    self.screen = .signInRequired
                } else {
                    self.screen = .failed(message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription, canRetry: true)
                }
                self.publish()
            })
    }

    // MARK: State

    private func publish() {
        view?.render(makeState())
    }

    private func makeState() -> ScenarioListState {
        var state = ScenarioListState()
        state.screen = screen
        guard !catalogue.isEmpty, screen == .content else { return state }
        state.totalText = String.localizedStringWithFormat(NSLocalizedString("%lld situations", comment: "Size of the situation catalogue"), catalogue.count)
        let keys = Set(catalogue.map(\.categoryKey)).sorted(by: ScenarioCategory.sortsBefore)
        state.chips = keys.map { ScenarioChipState(key: $0, title: ScenarioCategory.title(forKey: $0),
                                                   symbol: ScenarioCategory.symbol(forKey: $0), isSelected: $0 == category) }
        let shown = Self.filter(catalogue, query: query, category: category)
        if shown.isEmpty {
            state.screen = .noMatches(query: query)
            return state
        }
        state.screen = .content
        state.sections = keys.compactMap { key in
            let rows = shown.filter { $0.categoryKey == key }.map(Self.row)
            return rows.isEmpty ? nil : ScenarioSectionState(key: key, title: ScenarioCategory.title(forKey: key),
                                                             symbol: ScenarioCategory.symbol(forKey: key), rows: rows)
        }
        return state
    }

    static func row(_ summary: ScenarioSummary) -> ScenarioRowState {
        let minutes = String.localizedStringWithFormat(NSLocalizedString("%lld min", comment: "Minutes a situation takes"), summary.minutes)
        let steps = String.localizedStringWithFormat(NSLocalizedString("%lld steps", comment: "Steps in a situation"), summary.stepCount)
        return ScenarioRowState(id: summary.id, title: summary.title.primary, subtitle: summary.title.secondary, meta: "\(minutes) · \(steps)")
    }

    /// Keeps the order of the server. A search matches whatever the learner types in either language, ignoring case and accents
    /// (so "cat toc" finds "cắt tóc").
    static func filter(_ list: [ScenarioSummary], query: String, category: String?) -> [ScenarioSummary] {
        let words = fold(query).split(separator: " ").map(String.init)
        return list.filter { summary in
            if let category, summary.categoryKey != category { return false }
            guard !words.isEmpty else { return true }
            let haystack = fold(summary.searchText)
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "đ", with: "d")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ScenarioListPresenter: ScenarioListPresenterInterface {
    func viewDidLoad() { load() }

    /// Coming back after signing in, or after a long time away, shows the catalogue again; coming back from a situation does not reload it.
    func viewWillAppear() {
        if !loaded, case .signInRequired = screen { load() }
    }

    func retry() { load() }

    func signIn() {
        wireframe.showSignIn { [weak self] in self?.load() }
    }

    func search(_ query: String) {
        self.query = query
        guard loaded else { return }
        screen = .content
        publish()
    }

    func toggleCategory(_ key: String) {
        category = category == key ? nil : key
        guard loaded else { return }
        screen = .content
        publish()
    }

    func select(id: String) {
        guard let summary = catalogue.first(where: { $0.id == id }) else { return }
        // The next situation follows the order the learner sees, so "next" never jumps to a group they filtered out.
        let shown = Self.filter(catalogue, query: query, category: category)
        let keys = Set(shown.map(\.categoryKey)).sorted(by: ScenarioCategory.sortsBefore)
        let ordered = keys.flatMap { key in shown.filter { $0.categoryKey == key } }
        wireframe.showScenario(summary, ordered: ordered)
    }
}
