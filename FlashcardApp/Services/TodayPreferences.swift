import Foundation

/// What the learner chose on Today, per learner: the deck they study and how long a session may take. Device-local, like the
/// other preferences; the signed-in account's id, or "" with nobody signed in, keeps one learner's choice from another's.
protocol TodayPreferencesInterface: AnyObject {
    func selectedDeckID(ownerKey: String) -> String?
    func setSelectedDeckID(_ id: String?, ownerKey: String)
    func budgetMinutes(ownerKey: String) -> Int
    func setBudgetMinutes(_ minutes: Int, ownerKey: String)
}

final class UserDefaultsTodayPreferences: TodayPreferencesInterface {
    static let shared = UserDefaultsTodayPreferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func deckKey(_ ownerKey: String) -> String { "com.flashcardapp.today.deck.\(ownerKey)" }
    private func budgetKey(_ ownerKey: String) -> String { "com.flashcardapp.today.budget.\(ownerKey)" }

    func selectedDeckID(ownerKey: String) -> String? {
        defaults.string(forKey: deckKey(ownerKey))
    }

    func setSelectedDeckID(_ id: String?, ownerKey: String) {
        if let id { defaults.set(id, forKey: deckKey(ownerKey)) } else { defaults.removeObject(forKey: deckKey(ownerKey)) }
    }

    /// Only the offered times; anything else (nothing stored, or a value from elsewhere) is the default.
    func budgetMinutes(ownerKey: String) -> Int {
        TodayBudget(minutes: defaults.integer(forKey: budgetKey(ownerKey))).minutes
    }

    func setBudgetMinutes(_ minutes: Int, ownerKey: String) {
        defaults.set(TodayBudget(minutes: minutes).minutes, forKey: budgetKey(ownerKey))
    }
}
