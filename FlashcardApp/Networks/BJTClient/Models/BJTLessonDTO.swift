import Foundation

/// One row of `GET /levels/{code}/lessons`. Every field was present on all 84 J5 rows of the production response
/// (2026-11-11), so a missing one is a contract change and fails decoding instead of showing a blank row.
struct BJTLessonSummaryDTO: Decodable, Equatable {
    let id: String
    let slug: String
    let titleVi: String
    let titleJa: String
    let descriptionVi: String
    let descriptionJa: String
    let weekNumber: Int
    /// Position inside the level; the list is already in this order.
    let sortOrder: Int
    /// Position inside the week.
    let unitOrder: Int
    /// `lesson`, `review` or `checkpoint` today. Kept as sent: an unknown value is shown, not rejected.
    let unitType: String
    let estimatedDurationMin: Int
    let vocabCount: Int
    let grammarCount: Int
    let kanjiCount: Int
    let activityCount: Int
    /// Only meaningful when the request carried a session; the public (anonymous) read always answers `false`.
    let isCompleted: Bool
}

/// `GET /levels/lessons/{slug}`. The teaching material is in `lessonContent`; the top-level `contents` array is empty on
/// every lesson and is deliberately not modelled.
struct BJTLessonDetailDTO: Decodable, Equatable {
    let id: String
    let slug: String
    let levelCode: String
    let titleVi: String
    let titleJa: String
    let descriptionVi: String?
    let descriptionJa: String?
    let weekNumber: Int
    let sortOrder: Int
    let unitType: String
    let unitOrder: Int
    let estimatedDurationMin: Int?
    let difficulty: String?
    let skillTags: [String]
    let businessTopics: [String]
    let contentVersion: String?
    let lessonContent: BJTLessonContentDTO
    let prevLesson: BJTLessonNeighborDTO?
    let nextLesson: BJTLessonNeighborDTO?
    let isCompleted: Bool
    /// `false` for an anonymous reader; the server only accepts a progress write from a signed-in learner.
    let canSaveProgress: Bool

    private enum CodingKeys: String, CodingKey {
        case id, slug, levelCode, titleVi, titleJa, descriptionVi, descriptionJa, weekNumber, sortOrder, unitType, unitOrder
        case estimatedDurationMin, difficulty, skillTags, businessTopics, contentVersion, lessonContent
        case prevLesson, nextLesson, isCompleted, canSaveProgress
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        slug = try c.decode(String.self, forKey: .slug)
        levelCode = try c.decode(String.self, forKey: .levelCode)
        titleVi = try c.decode(String.self, forKey: .titleVi)
        titleJa = try c.decode(String.self, forKey: .titleJa)
        descriptionVi = try c.decodeIfPresent(String.self, forKey: .descriptionVi)
        descriptionJa = try c.decodeIfPresent(String.self, forKey: .descriptionJa)
        weekNumber = try c.decode(Int.self, forKey: .weekNumber)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        unitType = try c.decode(String.self, forKey: .unitType)
        unitOrder = try c.decode(Int.self, forKey: .unitOrder)
        estimatedDurationMin = try c.decodeIfPresent(Int.self, forKey: .estimatedDurationMin)
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty)
        skillTags = try c.decodeIfPresent([String].self, forKey: .skillTags) ?? []
        businessTopics = try c.decodeIfPresent([String].self, forKey: .businessTopics) ?? []
        contentVersion = try c.decodeIfPresent(String.self, forKey: .contentVersion)
        // A lesson without `lessonContent` is a broken lesson, never an empty one.
        lessonContent = try c.decode(BJTLessonContentDTO.self, forKey: .lessonContent)
        prevLesson = try c.decodeIfPresent(BJTLessonNeighborDTO.self, forKey: .prevLesson)
        nextLesson = try c.decodeIfPresent(BJTLessonNeighborDTO.self, forKey: .nextLesson)
        isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        canSaveProgress = try c.decode(Bool.self, forKey: .canSaveProgress)
    }
}

struct BJTLessonNeighborDTO: Decodable, Equatable {
    let slug: String
    let titleVi: String
    let sortOrder: Int
}

/// The lesson body. Sections the server may leave out decode as empty; the activities are validated strictly.
struct BJTLessonContentDTO: Decodable, Equatable {
    let schemaVersion: String?
    let summaryVi: [String]
    let learningObjectives: [String]
    let knowledgePoints: [String]
    let workplaceScenario: BJTLessonScenarioDTO?
    let vocabulary: [BJTLessonVocabularyDTO]
    let grammar: [BJTLessonGrammarDTO]
    let examples: [BJTLessonExampleDTO]
    let nuanceNotesVi: [String]
    let vietnameseLearnerPitfalls: [String]
    let businessUsageVi: String?
    let politenessHierarchyVi: String?
    let activities: [BJTLessonActivityDTO]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, summaryVi, learningObjectives, knowledgePoints, workplaceScenario, vocabulary, grammar, examples
        case nuanceNotesVi, vietnameseLearnerPitfalls, businessUsageVi, politenessHierarchyVi, activities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(String.self, forKey: .schemaVersion)
        summaryVi = try c.decodeIfPresent([String].self, forKey: .summaryVi) ?? []
        learningObjectives = try c.decodeIfPresent([String].self, forKey: .learningObjectives) ?? []
        knowledgePoints = try c.decodeIfPresent([String].self, forKey: .knowledgePoints) ?? []
        workplaceScenario = try c.decodeIfPresent(BJTLessonScenarioDTO.self, forKey: .workplaceScenario)
        vocabulary = try c.decodeIfPresent([BJTLessonVocabularyDTO].self, forKey: .vocabulary) ?? []
        grammar = try c.decodeIfPresent([BJTLessonGrammarDTO].self, forKey: .grammar) ?? []
        examples = try c.decodeIfPresent([BJTLessonExampleDTO].self, forKey: .examples) ?? []
        nuanceNotesVi = try c.decodeIfPresent([String].self, forKey: .nuanceNotesVi) ?? []
        vietnameseLearnerPitfalls = try c.decodeIfPresent([String].self, forKey: .vietnameseLearnerPitfalls) ?? []
        businessUsageVi = try c.decodeIfPresent(String.self, forKey: .businessUsageVi)
        politenessHierarchyVi = try c.decodeIfPresent(String.self, forKey: .politenessHierarchyVi)
        // Required: an absent/null list would read as a lesson with nothing to practise. An explicit empty list is legitimate.
        activities = try c.decode([BJTLessonActivityDTO].self, forKey: .activities)
    }
}

struct BJTLessonScenarioDTO: Decodable, Equatable {
    let who: String?
    let counterpart: String?
    let relationship: String?
    let contextJa: String?
    let contextVi: String?
    let goalVi: String?
    let problemVi: String?
    let desiredOutcomeVi: String?
}

struct BJTLessonVocabularyDTO: Decodable, Equatable {
    let japanese: String
    let reading: String?
    let meaningVi: String
}

struct BJTLessonGrammarDTO: Decodable, Equatable {
    let pattern: String
    let explanationVi: String
}

struct BJTLessonExampleDTO: Decodable, Equatable {
    let japanese: String
    let vietnamese: String
    let noteVi: String?
}

/// A multiple-choice activity. Decoding rejects an activity whose answer cannot be trusted: fewer than two options,
/// duplicate option keys, an `answer` that names no option, or `isCorrect` flags that disagree with `answer`.
struct BJTLessonActivityDTO: Decodable, Equatable {
    let id: String
    let questionType: String
    let prompt: String
    let promptVi: String?
    let stimulusType: String?
    let stimulusText: String?
    let scenarioJa: String?
    let scenarioVi: String?
    let skillTag: String?
    let difficulty: String?
    let options: [Option]
    /// The `key` of the correct option, as the server states it.
    let answer: String
    let explanationJa: String?
    let explanationVi: String?
    /// Audio is not produced yet (`audioUrl` is null on every activity); kept so a later reader can tell "no audio" from "unknown".
    let audioUrl: String?

    struct Option: Decodable, Equatable {
        let key: String
        let text: String
        let isCorrect: Bool
        let rationaleVi: String?
    }

    private enum CodingKeys: String, CodingKey {
        case id, questionType, prompt, promptVi, stimulusType, stimulusText, scenarioJa, scenarioVi, skillTag, difficulty
        case options, answer, explanationJa, explanationVi, audioUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        questionType = try c.decode(String.self, forKey: .questionType)
        prompt = try c.decode(String.self, forKey: .prompt)
        promptVi = try c.decodeIfPresent(String.self, forKey: .promptVi)
        stimulusType = try c.decodeIfPresent(String.self, forKey: .stimulusType)
        stimulusText = try c.decodeIfPresent(String.self, forKey: .stimulusText)
        scenarioJa = try c.decodeIfPresent(String.self, forKey: .scenarioJa)
        scenarioVi = try c.decodeIfPresent(String.self, forKey: .scenarioVi)
        skillTag = try c.decodeIfPresent(String.self, forKey: .skillTag)
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty)
        options = try c.decode([Option].self, forKey: .options)
        answer = try c.decode(String.self, forKey: .answer)
        explanationJa = try c.decodeIfPresent(String.self, forKey: .explanationJa)
        explanationVi = try c.decodeIfPresent(String.self, forKey: .explanationVi)
        audioUrl = try c.decodeIfPresent(String.self, forKey: .audioUrl)

        let keys = options.map(\.key)
        let correct = options.filter(\.isCorrect).map(\.key)
        guard options.count >= 2, Set(keys).count == keys.count, correct == [answer] else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath + [CodingKeys.answer],
                                                    debugDescription: "Activity \(id) has an answer that does not match its options"))
        }
    }
}

/// `PUT /levels/lessons/{slug}/progress` answers `{"isCompleted": <the value that was sent>}`.
struct BJTLessonProgressDTO: Decodable, Equatable {
    let isCompleted: Bool
}
