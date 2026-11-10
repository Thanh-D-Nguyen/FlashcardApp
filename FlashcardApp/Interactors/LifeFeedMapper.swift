//
//  LifeFeedMapper.swift
//
//  Turns the server's feed (or a lesson of any source) into the cards the hub shows. A card the app cannot teach honestly (unknown
//  provenance, a lesson that breaks the contract) is left out; an unknown topic is ignored, so the server can add topics freely.
//

import Foundation

enum LifeFeedMapper {
    /// The card of a ready lesson, in the learner's language.
    static func card(for lesson: LifeLesson, language: AppLanguage) -> LifeFeedCard {
        let summary = (lesson.sentences.first ?? LifeLesson.Sentence(id: "", isAdvice: false, japanese: "", reading: "", translation: LifeText(vi: "", en: ""), explanation: LifeText(vi: "", en: ""))).translation.resolved(language)
        let minutes = String.localizedStringWithFormat(NSLocalizedString("About %lld minutes", comment: ""), lesson.estimatedMinutes)
        let meta = [minutes, lesson.level].joined(separator: " · ")
        return LifeFeedCard(id: lesson.id, topic: lesson.topic, status: .ready, provenance: lesson.provenance,
                            eyebrow: lesson.topic.title.uppercased(), headlineJapanese: lesson.titleJapanese, reading: lesson.titleReading,
                            summary: summary, chips: lesson.chips, meta: meta,
                            scene: LifeLessonPresenter.scene(for: lesson),
                            ctaTitle: NSLocalizedString("Learn this lesson", comment: ""), lesson: lesson)
    }

    /// The valid cards of a feed in the server's order. Throws `invalidResponse` when the feed itself is broken or nothing in it is usable.
    static func cards(from dto: BJTLifeFeedDTO, requestedCityID: String, language: AppLanguage) throws -> [LifeFeedCard] {
        guard dto.schemaVersion == 1, dto.cityId == requestedCityID else { throw LearnerAPIError.invalidResponse }
        var seen = Set<String>()
        let cards = dto.cards.compactMap { entry -> LifeFeedCard? in
            guard seen.insert(entry.id).inserted,
                  let lesson = try? lesson(from: entry, requestedCityID: requestedCityID, language: language) else { return nil }
            return card(for: lesson, language: language)
        }
        if !dto.cards.isEmpty, cards.isEmpty { throw LearnerAPIError.invalidResponse }
        return cards
    }

    static func lesson(from card: BJTLifeFeedDTO.Card, requestedCityID: String, language: AppLanguage) throws -> LifeLesson {
        guard let topic = LifeTopic(rawValue: card.topic), card.provenance == "live" || card.provenance == "sample",
              let provenance = LifeProvenance(rawValue: card.provenance), let scene = scene(from: card.scene, topic: topic) else {
            throw LearnerAPIError.invalidResponse
        }
        let dto = card.lesson
        let url = try dto.source.url.map { text -> URL in
            guard let url = URL(string: text), url.scheme == "https" else { throw LearnerAPIError.invalidResponse }
            return url
        }
        guard let observedAt = LifeLessonInteractor.parseDate(dto.source.observedAt), let fetchedAt = LifeLessonInteractor.parseDate(dto.source.fetchedAt),
              let expiresAt = LifeLessonInteractor.parseDate(dto.source.expiresAt), let freshness = LifeLesson.Freshness(rawValue: dto.source.freshness),
              !dto.sentences.isEmpty, !dto.vocabulary.isEmpty, !dto.exercises.isEmpty else { throw LearnerAPIError.invalidResponse }
        let licence = dto.source.licenseStatus.flatMap(LifeLesson.LicenseStatus.init(rawValue:)) ?? .notApplicable
        let exercises = try dto.exercises.map { try LifeLessonInteractor.exercise(from: $0) }
        let text = { (value: BJTLifeTextDTO) in LifeText(vi: value.vi, en: value.en) }
        return LifeLesson(
            id: dto.id, topic: topic, provenance: provenance, level: dto.level, cityID: requestedCityID,
            titleJapanese: dto.title.japanese, titleReading: dto.title.reading, title: LifeText(vi: dto.title.vi, en: dto.title.en),
            source: LifeLesson.Source(providerName: dto.source.providerName, url: url, attributionText: dto.source.attributionText, licenseName: "",
                                      licenseStatus: licence, observedAt: observedAt, fetchedAt: fetchedAt, expiresAt: expiresAt, freshness: freshness),
            facts: nil, chips: dto.chips.map { LifeChip(symbol: $0.symbol, text: text($0.text).resolved(language)) }, scene: scene,
            sentences: dto.sentences.map {
                LifeLesson.Sentence(id: $0.id, isAdvice: $0.basis == "advice", japanese: $0.japanese, reading: $0.reading,
                                    translation: text($0.translations), explanation: text($0.explanation))
            },
            vocabulary: dto.vocabulary.map { LifeLesson.Vocabulary(id: $0.id, japanese: $0.japanese, reading: $0.reading, meaning: text($0.meanings), example: $0.exampleJapanese) },
            exercises: exercises, estimatedMinutes: max(dto.estimatedMinutes, 1),
            cityName: LifeText(vi: topic.title, en: topic.title), cityNameJapanese: "")
    }

    private static func scene(from dto: BJTLifeFeedDTO.Scene, topic: LifeTopic) -> LifeScene? {
        switch dto.kind {
        case "weather":
            guard let code = dto.weatherCode else { return nil }
            return .weather(LifeWeatherKind(wmoCode: code), temperatureC: dto.temperatureC.flatMap { $0.isFinite && abs($0) <= 150 ? Int($0.rounded()) : nil })
        case "date":
            guard let day = dto.day, (1...31).contains(day) else { return nil }
            return .date(day: day, weekday: dto.weekday ?? "")
        case "place": return .place
        case "transit": return .transit
        case "shopping": return .shopping
        case "news": return .news
        case "food": return .food
        case "culture": return .culture
        case "money": return .money
        case "lottery": return .lottery
        default: return nil
        }
    }
}
