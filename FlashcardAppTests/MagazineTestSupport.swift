import Foundation
import RxSwift
@testable import FlashcardApp

/// Payloads shaped like the live `/api/magazine` replies (checked 2026-10-29), cut down to what the tests need.
enum MagazineFixtures {
    static func listItem(slug: String, kind: String = "magazine_vocab", day: String = "2026-10-26", level: String? = "N4", words: [String] = ["梅雨"]) -> String {
        let wordJSON = words.map { #"{"word":"\#($0)","reading":"よみ","meaning":"nghĩa"}"# }.joined(separator: ",")
        let levelJSON = level.map { #""jlptLevel":"\#($0)","# } ?? ""
        return #"{"id":"id-\#(slug)","slug":"\#(slug)","widgetKind":"\#(kind)","titleJp":"題 \#(slug)","titleVi":"Tiêu đề \#(slug)","summaryVi":"Tóm tắt",\#(levelJSON)"publishDate":"\#(day)","publishedAt":"\#(day)T00:00:00Z","vocabWords":[\#(wordJSON)]}"#
    }

    static func list(_ items: [String], page: Int = 1, limit: Int = 20, total: Int? = nil) -> String {
        #"{"data":[\#(items.joined(separator: ","))],"limit":\#(limit),"page":\#(page),"total":\#(total ?? items.count)}"#
    }

    static let vocabularyArticle = #"""
    {"id":"a1","slug":"2026-10-26-vocab-vi","widgetKind":"magazine_vocab","titleJp":"梅雨の季節の言葉","titleVi":"Từ vựng mùa mưa",
     "summaryJp":"梅雨の時期に使う日本語の表現を学びましょう。","summaryVi":"Học các từ vựng mùa mưa.",
     "contentJson":{"theme":"rainy_season","introduction":"6月から7月にかけて、日本は梅雨の季節を迎えます。","introductionVi":"Từ tháng 6 đến tháng 7, Nhật Bản bước vào mùa mưa."},
     "jlptLevel":"N4","publishedAt":"2026-10-26T00:00:00Z",
     "vocabItems":[
       {"id":"v1","wordJp":"梅雨","reading":"つゆ","meaningVi":"Mùa mưa","jlptLevel":"N3","exampleJp":"今年の梅雨は長引きそうです。","exampleVi":"Mùa mưa năm nay có vẻ kéo dài."},
       {"id":"v2","wordJp":"傘","reading":"かさ","meaningVi":"Cái ô","jlptLevel":"N5","exampleJp":"傘を持っていきましょう。","exampleVi":"Hãy mang ô."}],
     "quizzes":[
       {"questionJp":"「梅雨」の読み方はどれですか？","questionVi":"Cách đọc của 梅雨?","options":[{"label":"つゆ","isCorrect":true},{"label":"ばいう","isCorrect":false},{"label":"うめ","isCorrect":false}],
        "explanationJp":"「つゆ」と読みます。","explanationVi":"Đọc là つゆ."},
       {"questionJp":"「傘」の意味は？","options":[{"label":"ô","isCorrect":true},{"label":"giày","isCorrect":false}]}]}
    """#

    static let phraseArticle = #"""
    {"id":"a2","slug":"2026-10-26-bjt_phrase-vi","widgetKind":"magazine_bjt_phrase","titleJp":"ビジネス日本語：お疲れ様です","titleVi":"Tiếng Nhật thương mại",
     "contentJson":{"phrase":"お疲れ様です","phraseReading":"おつかれさまです","literalMeaning":"Bạn đã vất vả rồi","formality":"polite",
       "dialogue":[{"speaker":"田中","text":"お疲れ様です。","textVi":"Chào anh."},{"speaker":"山田","text":"お疲れ様です。はい。"}],
       "usageNote":"万能な挨拶表現。","usageNoteVi":"Lời chào đa năng.",
       "situations":["会議の終わりに","メールの冒頭"],"situationsVi":["Cuối buổi họp"]},
     "jlptLevel":"N3","publishedAt":"2026-10-26T00:00:00Z","vocabItems":[],"quizzes":[]}
    """#

    static let weatherArticle = #"""
    {"id":"a3","slug":"2026-10-08-weather-vi","widgetKind":"magazine_weather","titleJp":"今日の天気","titleVi":"Thời tiết hôm nay",
     "contentJson":{"city":"東京","lowTemp":21.6,"highTemp":28,"humidity":85,"uvIndex":3,"description":"曇り時々雨","descriptionVi":"Nhiều mây","weatherIcon":"cloudy_rain",
       "recommendation":"傘を持って出かけましょう。","recommendationVi":"Hãy mang ô."},"jlptLevel":"N4","vocabItems":[],"quizzes":[]}
    """#

    static let horoscopeArticle = #"""
    {"id":"a4","slug":"2026-10-08-horoscope-vi","widgetKind":"magazine_horoscope","titleJp":"今日の星占い","titleVi":"Tử vi",
     "contentJson":{"zodiacFortunes":[
       {"sign":"牡羊座","signVi":"Bạch Dương","signReading":"おひつじざ","fortune":"大吉","fortuneVi":"Đại cát","message":"挑戦しましょう。","messageVi":"Hãy thử thách.","luckyColor":"赤","luckyNumber":7},
       {"signVi":"thiếu dấu hiệu"}]},"jlptLevel":"N3","vocabItems":[],"quizzes":[]}
    """#

    static func decodeArticle(_ json: String) throws -> BJTMagazineArticleDTO {
        try JSONDecoder().decode(BJTMagazineArticleDTO.self, from: Data(json.utf8))
    }

    static func article(_ json: String = vocabularyArticle) throws -> MagazineArticle {
        try MagazineInteractor.article(from: decodeArticle(json))
    }

    static func summary(_ slug: String, kind: MagazineKind = .vocabulary, day: String? = "2026-10-26") -> MagazineSummary {
        MagazineSummary(id: "id-\(slug)", slug: slug, kind: kind, titleJapanese: "題 \(slug)", titleVietnamese: "Tiêu đề \(slug)",
                        summary: nil, level: "N4", day: day.flatMap(MagazineDay.init(key:)), words: ["梅雨"])
    }
}

final class FakeMagazineAPI: BJTMagazineAPIInterface {
    var listCalls: [(kind: MagazineKind?, page: Int, limit: Int)] = []
    var articleCalls: [String] = []
    var listResult: (MagazineKind?, Int) -> Single<BJTMagazineListDTO> = { _, _ in .error(LearnerAPIError.offline) }
    var articleResult: (String) -> Single<BJTMagazineArticleDTO> = { _ in .error(LearnerAPIError.offline) }

    func articles(kind: MagazineKind?, page: Int, limit: Int) -> Single<BJTMagazineListDTO> {
        listCalls.append((kind, page, limit))
        return listResult(kind, page)
    }

    func article(slug: String) -> Single<BJTMagazineArticleDTO> {
        articleCalls.append(slug)
        return articleResult(slug)
    }
}

final class FakeMagazineInteractor: MagazineInteractorInterface {
    var pageCalls: [(kind: MagazineKind?, page: Int)] = []
    var pageResult: (MagazineKind?, Int) -> Single<MagazinePage> = { _, _ in .error(LearnerAPIError.offline) }
    var articleCalls: [String] = []
    var articleResult: (String) -> Single<MagazineArticle> = { _ in .error(LearnerAPIError.offline) }
    var choices: [TodayDeckChoice] = []
    var deckPresent = false
    var saveCalls: [(words: [MagazineArticle.Vocabulary], target: MagazineSaveTarget)] = []
    var saveResult: Result<MagazineSaveOutcome, Error> = .success(MagazineSaveOutcome(deckID: "magazine", deckName: "Magazine", added: [], alreadyPresent: [], cardIDs: []))

    func loadPage(kind: MagazineKind?, page: Int) -> Single<MagazinePage> {
        pageCalls.append((kind, page))
        return pageResult(kind, page)
    }

    func loadArticle(slug: String) -> Single<MagazineArticle> {
        articleCalls.append(slug)
        return articleResult(slug)
    }

    func deckChoices() -> [TodayDeckChoice] { choices }
    func magazineDeckExists() -> Bool { deckPresent }

    func saveVocabulary(_ words: [MagazineArticle.Vocabulary], target: MagazineSaveTarget) throws -> MagazineSaveOutcome {
        saveCalls.append((words, target))
        return try saveResult.get()
    }
}

final class FakeMagazineWireframe: MagazineWireframeInterface {
    var opened: [(slug: String, day: MagazineDay?)] = []
    func showArticle(slug: String, day: MagazineDay?) { opened.append((slug, day)) }
}

final class FakeMagazineArticleWireframe: MagazineArticleWireframeInterface {
    var chooserCalls: [(choices: [TodayDeckChoice], deckExists: Bool, selected: MagazineSaveTarget)] = []
    var onSelect: ((MagazineSaveTarget) -> Void)?
    var studied: [(deck: String, cards: [String])] = []

    func showDeckChooser(_ choices: [TodayDeckChoice], magazineDeckExists: Bool, selected: MagazineSaveTarget, onSelect: @escaping (MagazineSaveTarget) -> Void) {
        chooserCalls.append((choices, magazineDeckExists, selected))
        self.onSelect = onSelect
    }

    func showStudy(deckId: String, cardIDs: [String]) { studied.append((deckId, cardIDs)) }
}

final class SpyMagazineView: MagazineViewInterface {
    var states: [MagazineViewState] = []
    var endedRefreshing = 0
    var last: MagazineViewState? { states.last }
    func render(_ state: MagazineViewState) { states.append(state) }
    func endRefreshing() { endedRefreshing += 1 }
}

final class SpyMagazineArticleView: MagazineArticleViewInterface {
    var states: [MagazineArticleViewState] = []
    var announcements: [String] = []
    var last: MagazineArticleViewState? { states.last }
    var article: MagazineArticleState? { if case .article(let state)? = states.last { return state } else { return nil } }
    func render(_ state: MagazineArticleViewState) { states.append(state) }
    func announce(_ text: String) { announcements.append(text) }
}
