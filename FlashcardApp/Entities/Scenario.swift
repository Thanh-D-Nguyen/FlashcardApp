import Foundation

/// The groups of the website's situation catalogue. The server sends the key; the app only knows how to name and order the groups it
/// has seen, and shows any other key as plain words instead of dropping the situations.
enum ScenarioCategory: String, CaseIterable {
    case arrival, admin, housing, shopping, dining, transport, health, beauty, banking, utilities, delivery, repair
    case family, community, emergency, work, email

    var title: String {
        switch self {
        case .arrival: return NSLocalizedString("Arriving in Japan", comment: "Situation group")
        case .admin: return NSLocalizedString("Offices and paperwork", comment: "Situation group")
        case .housing: return NSLocalizedString("Housing", comment: "Situation group")
        case .shopping: return NSLocalizedString("Shopping", comment: "Situation group")
        case .dining: return NSLocalizedString("Eating out", comment: "Situation group")
        case .transport: return NSLocalizedString("Getting around", comment: "Situation group")
        case .health: return NSLocalizedString("Health and hospital", comment: "Situation group")
        case .beauty: return NSLocalizedString("Hair and beauty", comment: "Situation group")
        case .banking: return NSLocalizedString("Banking", comment: "Situation group")
        case .utilities: return NSLocalizedString("Utilities and phone", comment: "Situation group")
        case .delivery: return NSLocalizedString("Deliveries", comment: "Situation group")
        case .repair: return NSLocalizedString("Repairs", comment: "Situation group")
        case .family: return NSLocalizedString("Family", comment: "Situation group")
        case .community: return NSLocalizedString("Neighbours and community", comment: "Situation group")
        case .emergency: return NSLocalizedString("Emergencies", comment: "Situation group")
        case .work: return NSLocalizedString("Work", comment: "Situation group")
        case .email: return NSLocalizedString("Writing emails", comment: "Situation group")
        }
    }

    /// SF Symbols that exist on iOS 26; the emoji the server sends is the same for the whole catalogue, so it tells groups apart no better.
    var symbol: String {
        switch self {
        case .arrival: return "airplane.arrival"
        case .admin: return "building.columns"
        case .housing: return "house"
        case .shopping: return "bag"
        case .dining: return "fork.knife"
        case .transport: return "tram"
        case .health: return "cross.case"
        case .beauty: return "scissors"
        case .banking: return "banknote"
        case .utilities: return "bolt"
        case .delivery: return "shippingbox"
        case .repair: return "wrench.and.screwdriver"
        case .family: return "figure.2.and.child.holdinghands"
        case .community: return "person.3"
        case .emergency: return "exclamationmark.triangle"
        case .work: return "briefcase"
        case .email: return "envelope"
        }
    }

    static func title(forKey key: String) -> String {
        if let known = ScenarioCategory(rawValue: key) { return known.title }
        let words = key.replacingOccurrences(of: "[_-]+", with: " ", options: .regularExpression)
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    static func symbol(forKey key: String) -> String { ScenarioCategory(rawValue: key)?.symbol ?? "text.bubble" }

    /// Known groups first, in the order above; unknown ones after, alphabetically.
    static func sortsBefore(_ lhs: String, _ rhs: String) -> Bool {
        let order = { (key: String) -> Int in ScenarioCategory.allCases.firstIndex { $0.rawValue == key } ?? Int.max }
        let (left, right) = (order(lhs), order(rhs))
        return left == right ? lhs < rhs : left < right
    }
}

/// A piece of server text in the language the screen leads with, and the same text in the other language as its gloss.
/// The catalogue is written in Vietnamese and Japanese only: Vietnamese readers lead with their own language, everyone else
/// leads with the Japanese they are learning and keeps the Vietnamese as the only translation there is.
struct ScenarioText: Equatable {
    let primary: String
    let secondary: String?

    init(vietnamese: String, japanese: String?, language: AppLanguage) {
        let japanese = japanese?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if language == .vietnamese || japanese == nil {
            primary = vietnamese
            secondary = japanese
        } else {
            primary = japanese ?? vietnamese
            secondary = vietnamese
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct ScenarioSummary: Equatable {
    let id: String
    let categoryKey: String
    let title: ScenarioText
    /// Both languages, for searching whatever the learner types.
    let searchText: String
    let minutes: Int
    let stepCount: Int

    init(dto: BJTScenarioSummaryDTO, language: AppLanguage) {
        id = dto.id
        categoryKey = dto.category
        title = ScenarioText(vietnamese: dto.titleVi, japanese: dto.titleJa, language: language)
        searchText = [dto.titleVi, dto.titleJa, dto.descriptionVi, ScenarioCategory.title(forKey: dto.category)].compactMap { $0 }.joined(separator: " ")
        minutes = max(dto.estimatedMin, 1)
        stepCount = dto.count.steps
    }

    init(id: String, categoryKey: String, title: ScenarioText, searchText: String = "", minutes: Int = 2, stepCount: Int = 1) {
        self.id = id
        self.categoryKey = categoryKey
        self.title = title
        self.searchText = searchText
        self.minutes = minutes
        self.stepCount = stepCount
    }
}

struct ScenarioChoice: Equatable {
    let key: String
    /// The Japanese phrase is the lesson; the Vietnamese beside it is its meaning.
    let phrase: ScenarioText
    /// What is spoken aloud: the Japanese, when the choice has one.
    let japanese: String?
}

struct ScenarioStep: Equatable {
    let id: String
    let order: Int
    let situation: ScenarioText
    let speaker: String?
    let choices: [ScenarioChoice]
}

struct ScenarioLesson: Equatable {
    let id: String
    let title: ScenarioText
    let categoryKey: String
    let steps: [ScenarioStep]

    init(id: String, title: ScenarioText, categoryKey: String, steps: [ScenarioStep]) {
        self.id = id
        self.title = title
        self.categoryKey = categoryKey
        self.steps = steps
    }

    /// `nil` when the server sent nothing playable: no steps, or a step without two ways to answer.
    init?(dto: BJTScenarioDetailDTO, language: AppLanguage) {
        let steps = dto.steps.sorted { $0.stepOrder < $1.stepOrder }.map { step in
            ScenarioStep(id: step.id, order: step.stepOrder,
                         situation: ScenarioText(vietnamese: step.situationVi, japanese: step.situationJa, language: language),
                         speaker: step.speakerName.flatMap { $0.isEmpty ? nil : $0 },
                         choices: step.choices.map { choice in
                // The phrase to learn is Japanese whatever the screen's language is.
                let japanese = choice.textJa?.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasJapanese = japanese?.isEmpty == false
                return ScenarioChoice(key: choice.choiceKey,
                                      phrase: hasJapanese ? ScenarioText(vietnamese: choice.textVi, japanese: japanese, language: .japanese)
                                                          : ScenarioText(vietnamese: choice.textVi, japanese: nil, language: language),
                                      japanese: hasJapanese ? japanese : nil)
            })
        }
        guard !steps.isEmpty, steps.allSatisfy({ $0.choices.count >= 2 }) else { return nil }
        self.init(id: dto.id, title: ScenarioText(vietnamese: dto.titleVi, japanese: dto.titleJa, language: language),
                  categoryKey: dto.category, steps: steps)
    }
}

struct ScenarioAnswer: Equatable {
    let choiceKey: String
    let isNatural: Bool
    /// The server's note, in Vietnamese: shown to Vietnamese readers only.
    let noteVietnamese: String?

    init(dto: BJTScenarioAnswerDTO) {
        choiceKey = dto.choiceKey
        isNatural = dto.isOptimal
        noteVietnamese = dto.feedbackVi?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    init(choiceKey: String, isNatural: Bool, noteVietnamese: String? = nil) {
        self.choiceKey = choiceKey
        self.isNatural = isNatural
        self.noteVietnamese = noteVietnamese
    }
}
