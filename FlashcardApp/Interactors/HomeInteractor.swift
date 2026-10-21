import Foundation
import RxSwift

protocol HomeInteractorInterface: AnyObject {
    func listLevels() -> Single<[BJTLevelDTO]>
    func content(code: String, kind: HomeContentKind, offset: Int) -> Single<[HomeRow]>
}

final class HomeInteractor: HomeInteractorInterface {
    private let api: BJTLevelAPI

    init(api: BJTLevelAPI = .shared) { self.api = api }

    func listLevels() -> Single<[BJTLevelDTO]> { api.list() }

    func content(code: String, kind: HomeContentKind, offset: Int) -> Single<[HomeRow]> {
        switch kind {
        case .vocabulary:
            return api.vocabulary(code: code, offset: offset).map { items in
                items.map { item in
                    let meanings = item.senses.compactMap(\.meaningVi)
                    let summary = item.shortMeaningVi.flatMap { $0.isEmpty ? nil : $0 } ?? meanings.first
                    let detail = ([item.reading, item.shortMeaningVi].compactMap { $0 } + meanings)
                        .filter { !$0.isEmpty }.joined(separator: "\n")
                    return HomeRow(id: item.id, title: item.headword,
                                   subtitle: [item.reading, summary].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                                   detail: detail,
                                   reading: item.reading.flatMap { $0.isEmpty ? nil : $0 }, meaning: summary)
                }
            }
        case .kanji:
            return api.kanji(code: code, offset: offset).map { items in
                items.map { item in
                    let readings = [item.onyomi, item.kunyomi].compactMap { $0 }.filter { !$0.isEmpty }
                    return HomeRow(id: item.id, title: item.character,
                                   subtitle: ([item.meaningVi].compactMap { $0 } + readings).joined(separator: " · "),
                                   detail: ([item.meaningVi].compactMap { $0 } + readings).joined(separator: "\n"),
                                   reading: readings.isEmpty ? nil : readings.joined(separator: " · "),
                                   meaning: item.meaningVi.flatMap { $0.isEmpty ? nil : $0 })
                }
            }
        case .grammar:
            return api.grammar(code: code, offset: offset).map { items in
                items.map { item in
                    HomeRow(id: item.id, title: item.pattern, subtitle: item.meaningVi ?? "",
                            detail: ([item.meaningVi].compactMap { $0 } + item.details.compactMap(\.explanationVi))
                                .filter { !$0.isEmpty }.joined(separator: "\n"),
                            meaning: item.meaningVi.flatMap { $0.isEmpty ? nil : $0 })
                }
            }
        }
    }
}
