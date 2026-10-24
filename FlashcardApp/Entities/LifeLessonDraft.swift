//
//  LifeLessonDraft.swift
//
//  A compact way to write a lesson by hand or from on-device facts. The date, nearby and sample lessons are all built with it, so
//  they have the same shape as a lesson that comes from the server and go through the same screens, saving and checks.
//

import Foundation

struct LifeLessonDraft {
    struct Sentence {
        let id: String
        let japanese: String
        let reading: String
        let vi: String
        let en: String
        let explanationVi: String
        let explanationEn: String
        var isAdvice = false
    }

    struct Word {
        let id: String
        let japanese: String
        let reading: String
        let vi: String
        let en: String
        let example: String
    }

    struct Recall {
        let promptJapanese: String
        let cueVi: String
        let cueEn: String
        let accepted: [String]
        let explanationVi: String
        let explanationEn: String
    }

    struct Choice {
        let promptJapanese: String
        let promptVi: String
        let promptEn: String
        let options: [String]
        let correct: Int
        let explanationVi: String
        let explanationEn: String
    }

    let id: String
    let topic: LifeTopic
    let provenance: LifeProvenance
    var titleJapanese: String
    var titleReading: String
    var titleVi: String
    var titleEn: String
    var providerName: String
    var chips: [LifeChip]
    var scene: LifeScene
    var sentences: [Sentence]
    var words: [Word]
    var recall: Recall
    var choice: Choice
    var level = "N4"
    var minutes = 2
    var cityID = ""

    func build(now: Date, expiresAt: Date) -> LifeLesson {
        let topicTitle = topic.title
        return LifeLesson(
            id: id, topic: topic, provenance: provenance, level: level, cityID: cityID,
            titleJapanese: titleJapanese, titleReading: titleReading, title: LifeText(vi: titleVi, en: titleEn),
            source: LifeLesson.Source(providerName: providerName, url: nil, attributionText: nil, licenseName: "", licenseStatus: .notApplicable,
                                      observedAt: now, fetchedAt: now, expiresAt: expiresAt, freshness: .live),
            facts: nil, chips: chips, scene: scene,
            sentences: sentences.map {
                LifeLesson.Sentence(id: $0.id, isAdvice: $0.isAdvice, japanese: $0.japanese, reading: $0.reading,
                                    translation: LifeText(vi: $0.vi, en: $0.en), explanation: LifeText(vi: $0.explanationVi, en: $0.explanationEn))
            },
            vocabulary: words.map {
                LifeLesson.Vocabulary(id: $0.id, japanese: $0.japanese, reading: $0.reading, meaning: LifeText(vi: $0.vi, en: $0.en), example: $0.example)
            },
            exercises: [
                .recall(id: "recall", promptJapanese: recall.promptJapanese,
                        prompt: LifeText(vi: recall.cueVi, en: recall.cueEn), acceptedAnswers: recall.accepted,
                        explanation: LifeText(vi: recall.explanationVi, en: recall.explanationEn)),
                .choice(id: "choice", promptJapanese: choice.promptJapanese,
                        prompt: LifeText(vi: choice.promptVi, en: choice.promptEn),
                        choices: choice.options.enumerated().map { LifeLesson.Choice(id: String(UnicodeScalar(UInt8(97 + $0.offset))), text: $0.element) },
                        correctChoiceID: String(UnicodeScalar(UInt8(97 + choice.correct))),
                        explanation: LifeText(vi: choice.explanationVi, en: choice.explanationEn))
            ],
            estimatedMinutes: minutes,
            cityName: LifeText(vi: topicTitle, en: topicTitle), cityNameJapanese: "")
    }
}
