import Foundation

/// The city the learner picked for "Learn from Life", per learner like the other Today preferences. It is a choice made by
/// hand from a fixed list: the app never reads the device location for this.
protocol LifeLessonPreferencesInterface: AnyObject {
    func selectedCityID(ownerKey: String) -> String
    func setSelectedCityID(_ id: String, ownerKey: String)
}

final class UserDefaultsLifeLessonPreferences: LifeLessonPreferencesInterface {
    static let shared = UserDefaultsLifeLessonPreferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ ownerKey: String) -> String { "com.flashcardapp.life.city.\(ownerKey)" }

    /// Only a city of the fixed list; nothing stored, or a value from elsewhere, is the default.
    func selectedCityID(ownerKey: String) -> String {
        defaults.string(forKey: key(ownerKey)).flatMap { LifeCity.city(id: $0)?.id } ?? LifeCity.defaultID
    }

    func setSelectedCityID(_ id: String, ownerKey: String) {
        guard LifeCity.city(id: id) != nil else { return }
        defaults.set(id, forKey: key(ownerKey))
    }
}
