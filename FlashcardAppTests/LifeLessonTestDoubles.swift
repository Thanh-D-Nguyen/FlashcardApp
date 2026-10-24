import Foundation
import RxSwift
@testable import FlashcardApp

final class FakeLifeInteractor: LifeLessonInteractorInterface {
    var loadedCities: [String] = []
    /// What `loadWeather` answers; replace it to make a request wait on a subject.
    var loadResult: (String) -> Single<LifeLesson> = { _ in .error(LearnerAPIError.offline) }
    var city = "tokyo"
    var choices: [TodayDeckChoice] = []
    var lifeDeckPresent = false
    var saveCalls: [(words: [LifeLesson.Vocabulary], target: LifeSaveTarget, language: AppLanguage)] = []
    var saveResult: Result<LifeSaveOutcome, Error> = .success(LifeSaveOutcome(deckID: "life-learning", deckName: "Learn from Life", added: [], alreadyPresent: [], cardIDs: []))

    func loadWeather(cityID: String) -> Single<LifeLesson> {
        loadedCities.append(cityID)
        return loadResult(cityID)
    }

    func selectedCityID(ownerKey: String) -> String { city }
    func setSelectedCityID(_ id: String, ownerKey: String) { city = id }
    func deckChoices() -> [TodayDeckChoice] { choices }
    func lifeDeckExists() -> Bool { lifeDeckPresent }

    func saveVocabulary(_ words: [LifeLesson.Vocabulary], target: LifeSaveTarget, language: AppLanguage) throws -> LifeSaveOutcome {
        saveCalls.append((words, target, language))
        return try saveResult.get()
    }
}

final class FakeLifeWireframe: LifeLessonWireframeInterface {
    var chooserCalls: [(choices: [TodayDeckChoice], lifeDeckExists: Bool, selected: LifeSaveTarget)] = []
    var onSelect: ((LifeSaveTarget) -> Void)?
    var studied: [(deck: String, cards: [String])] = []
    var openedSources: [URL] = []
    var finished = 0

    func showDeckChooser(_ choices: [TodayDeckChoice], lifeDeckExists: Bool, selected: LifeSaveTarget, onSelect: @escaping (LifeSaveTarget) -> Void) {
        chooserCalls.append((choices, lifeDeckExists, selected))
        self.onSelect = onSelect
    }

    func showStudy(deckId: String, cardIDs: [String]) { studied.append((deckId, cardIDs)) }
    func openSource(_ url: URL) { openedSources.append(url) }
    func finish() { finished += 1 }
}

final class SpyLifeView: LifeLessonViewInterface {
    var states: [LifeLessonViewState] = []
    var announcements: [String] = []
    var last: LifeLessonViewState? { states.last }

    func render(_ state: LifeLessonViewState) { states.append(state) }
    func announce(_ text: String) { announcements.append(text) }
}
