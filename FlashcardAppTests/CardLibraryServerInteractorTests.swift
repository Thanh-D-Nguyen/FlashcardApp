import RealmSwift
import RxSwift
import XCTest
@testable import FlashcardApp

private final class SignedOutTokens: AuthTokenManagerInterface {
    var accessToken: String? { nil }
    var userId: String? { nil }
    func save(accessToken: String, userId: String) throws {}
    func clear() throws {}
}

private final class UnusedNativeAuth: NativeAuthAPIInterface {
    func login(email: String, password: String) -> Single<NativeLoginResponse> { fatalError() }
    func loginWithGoogle(idToken: String) -> Single<NativeLoginResponse> { fatalError() }
    func me(token: @escaping () -> String?) -> Single<NativeProfile> { fatalError() }
    func logout(token: @escaping () -> String?) -> Single<Void> { fatalError() }
}

private final class FakeLibraryAPI: BJTFlashcardLibraryAPIInterface {
    var decks: Single<[BJTDeckSummaryDTO]> = .just([])
    var deckResult: Single<BJTRemoteDeckDTO> = .error(LearnerAPIError.notFound)
    var due: Single<[BJTDueCardDTO]> = .just([])
    var submitResult: Single<Void> = .just(())
    var archiveResult: Single<Void> = .just(())
    private(set) var submissions: [(id: String, rating: ReviewRating, elapsedMs: Int?)] = []
    private(set) var deckLimits: [Int] = []

    func libraryDecks(limit: Int) -> Single<[BJTDeckSummaryDTO]> { deckLimits.append(limit); return decks }
    func deck(id: String) -> Single<BJTRemoteDeckDTO> { deckResult }
    func dueCards(limit: Int) -> Single<[BJTDueCardDTO]> { due }
    func submitReview(userFlashcardId: String, rating: ReviewRating, elapsedMs: Int?) -> Single<Void> {
        submissions.append((userFlashcardId, rating, elapsedMs))
        return submitResult
    }
    func archiveDeck(id: String) -> Single<Void> { archiveResult }
}

/// Mapping of server rows to the values the Cards tab shows, and the use cases that sit between the API and the device's decks.
final class CardLibraryServerInteractorTests: XCTestCase {
    private var api: FakeLibraryAPI!
    private var repository: DeskManagement!
    private var interactor: CardLibraryServerInteractor!
    private var language = AppLanguage.english
    private let deckId = "11111111-2222-4333-8444-555555555555"
    private let ufId = "99999999-2222-4333-8444-555555555555"

    override func setUpWithError() throws {
        let configuration = Realm.Configuration(inMemoryIdentifier: "library-\(UUID().uuidString)", objectTypes: RealmService.storedTypes)
        RealmService.shared.realm = try Realm(configuration: configuration)
        repository = DeskManagement()
        api = FakeLibraryAPI()
        interactor = CardLibraryServerInteractor(api: api, repository: repository,
                                                 auth: AuthSession(tokens: SignedOutTokens(), api: UnusedNativeAuth()),
                                                 language: { [unowned self] in language })
    }

    override func tearDownWithError() throws {
        RealmService.shared.realm = nil
    }

    private func value<T>(_ single: Single<T>) throws -> T {
        var outcome: Result<T, Error>?
        _ = single.subscribe(onSuccess: { outcome = .success($0) }, onFailure: { outcome = .failure($0) })
        return try XCTUnwrap(outcome, "The fake answers at once").get()
    }

    private func summary(_ id: String, owner: String? = nil, titleVi: String = "Từ vựng", titleJa: String? = nil, details: String? = nil,
                         detailsJa: String? = nil, visibility: String = "public", status: String = "active", count: Int = 4,
                         updated: String? = "2026-10-23T10:00:00.5Z") -> BJTDeckSummaryDTO {
        BJTDeckSummaryDTO(id: id, ownerUserId: owner, titleVi: titleVi, titleJa: titleJa, descriptionVi: details, descriptionJa: detailsJa,
                          visibility: visibility, status: status, cardCount: count, createdAt: "2026-10-01T00:00:00Z", updatedAt: updated)
    }

    private func remote(first: (String, String, String?) = ("犬", "chó", "いぬ")) -> BJTRemoteDeckDTO {
        func entry(_ id: String, _ position: Int, _ front: String, _ back: String, _ reading: String?) -> BJTRemoteDeckDTO.Entry {
            .init(id: id, position: position, card: .init(id: "v\(position)", frontText: front, backText: back, reading: reading, sourceId: "s", sourceType: "lexeme"))
        }
        return BJTRemoteDeckDTO(id: deckId, titleVi: "N5", cards: [
            entry("aaaaaaaa-0000-4000-8000-000000000002", 1, "猫", "mèo", nil),
            entry("aaaaaaaa-0000-4000-8000-000000000001", 0, first.0, first.1, first.2),
            entry("aaaaaaaa-0000-4000-8000-000000000003", 2, "  ", "bỏ", nil)
        ], descriptionVi: "Mô tả", visibility: "public")
    }

    // MARK: Deck list

    func test_decksAreMappedAndOnlyUsableOnesKept() throws {
        api.decks = .just([summary(deckId, owner: "me"), summary("not-a-uuid"), summary("22222222-2222-4333-8444-555555555555", status: "archived")])
        let decks = try value(interactor.decks())
        XCTAssertEqual(decks.map(\.id), [deckId])
        XCTAssertTrue(decks[0].isOwned)
        XCTAssertEqual(decks[0].cardCount, 4)
        XCTAssertEqual(api.deckLimits, [200])
    }

    func test_japaneseUsersSeeTheJapaneseTitleWhenThereIsOneAndVietnameseOtherwise() throws {
        api.decks = .just([summary(deckId, titleJa: "公開デッキ", details: "mô tả", detailsJa: "説明"),
                           summary("22222222-2222-4333-8444-555555555555", titleVi: "Chỉ Việt", titleJa: "  ", details: "chỉ có tiếng Việt")])
        language = .japanese
        var decks = try value(interactor.decks())
        XCTAssertEqual(decks.map(\.title), ["公開デッキ", "Chỉ Việt"])
        XCTAssertEqual(decks.map(\.details), ["説明", "chỉ có tiếng Việt"])
        language = .english
        decks = try value(interactor.decks())
        XCTAssertEqual(decks.map(\.title), ["Từ vựng", "Chỉ Việt"], "Only Japanese asks for the Japanese text")
    }

    func test_updatedAtReadsWithAndWithoutFractionalSecondsAndIsNilWhenMissing() {
        XCTAssertNotNil(ServerDeckMapper.date(from: "2026-10-22T10:00:00.123456Z"))
        XCTAssertNotNil(ServerDeckMapper.date(from: "2026-10-22T10:00:00Z"))
        XCTAssertNil(ServerDeckMapper.date(from: "yesterday"))
        XCTAssertNil(ServerDeckMapper.date(from: nil))
        let noDates = BJTDeckSummaryDTO(id: deckId, ownerUserId: nil, titleVi: "A", titleJa: nil, descriptionVi: nil, descriptionJa: nil,
                                        visibility: "weird", status: "active", cardCount: -3, createdAt: nil, updatedAt: nil)
        let deck = ServerDeckMapper.deck(from: noDates, language: .english)
        XCTAssertNil(deck.updatedAt)
        XCTAssertEqual(deck.visibility, .private, "An unknown visibility is treated as the safer private")
        XCTAssertEqual(deck.cardCount, 0)
    }

    func test_aFailedListPassesTheErrorOn() {
        api.decks = .error(LearnerAPIError.offline)
        XCTAssertThrowsError(try value(interactor.decks())) { XCTAssertEqual($0 as? LearnerAPIError, .offline) }
    }

    // MARK: Deck detail

    func test_detailKeepsPositionOrderTrimsAndDropsCardsWithAnEmptySide() throws {
        api.deckResult = .just(remote(first: ("犬", " chó ", " いぬ ")))
        let detail = try value(interactor.detail(deckId: deckId))
        XCTAssertEqual(detail.cards.map(\.front), ["犬", "猫"])
        XCTAssertEqual(detail.cards.map(\.back), ["chó", "mèo"])
        XCTAssertEqual(detail.cards.map(\.reading), ["いぬ", ""])
        XCTAssertEqual(detail.deck.details, "Mô tả")
        XCTAssertEqual(detail.deck.cardCount, 2, "The count is of cards that can be studied")
        XCTAssertFalse(detail.deck.isOwned)
    }

    func test_detailRefusesAnIdThatIsNotAUUID() {
        api.deckResult = .just(BJTRemoteDeckDTO(id: "x", titleVi: "N5", cards: []))
        XCTAssertThrowsError(try value(interactor.detail(deckId: deckId))) { XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse) }
    }

    // MARK: Due cards and ratings

    private func dueDTO(id: String, state: String = "learning", front: String = "食べる", back: String = "ăn", reading: String? = "たべる") -> BJTDueCardDTO {
        BJTDueCardDTO(id: id, cardId: "c", state: state, intervalDays: 1, lapses: 2, leeched: true,
                      card: .init(id: "c", frontText: front, backText: back, reading: reading))
    }

    func test_dueCardsAreMappedAndUnusableOnesSkipped() throws {
        api.due = .just([dueDTO(id: ufId), dueDTO(id: "bad-id"), dueDTO(id: "99999999-2222-4333-8444-555555555556", front: " "),
                         dueDTO(id: "99999999-2222-4333-8444-555555555557", state: "mystery", reading: nil)])
        let cards = try value(interactor.dueCards(limit: 50))
        XCTAssertEqual(cards.map(\.id), [ufId, "99999999-2222-4333-8444-555555555557"])
        XCTAssertEqual(cards[0].state, .learning)
        XCTAssertEqual(cards[0].lapses, 2)
        XCTAssertTrue(cards[0].isLeech)
        XCTAssertEqual(cards[1].state, .review, "An unknown schedule state reads as review")
        XCTAssertEqual(cards[1].reading, "")
    }

    func test_submitSendsMillisecondsRoundedAndNeverNegative() throws {
        let card = DueCard(id: ufId, state: .review, front: "a", back: "b", reading: "", lapses: 0, isLeech: false)
        _ = try value(interactor.submit(.good, for: card, elapsed: 4.2506))
        _ = try value(interactor.submit(.again, for: card, elapsed: -3))
        XCTAssertEqual(api.submissions.map(\.elapsedMs), [4251, 0])
        XCTAssertEqual(api.submissions.map(\.rating), [.good, .again])
        XCTAssertEqual(api.submissions.map(\.id), [ufId, ufId])
    }

    func test_archivePassesTheErrorOn() {
        api.archiveResult = .error(LearnerAPIError.forbidden("not owner"))
        XCTAssertThrowsError(try value(interactor.archive(deckId: deckId))) { XCTAssertEqual($0 as? LearnerAPIError, .forbidden("not owner")) }
    }

    func test_signedOutHasNoAccount() {
        XCTAssertFalse(interactor.isSignedIn)
        XCTAssertNil(interactor.accountId)
    }

    // MARK: Saving to the device

    func test_savingCopiesTheDeckWithTheServersIdsThenFindsTheCopy() throws {
        api.deckResult = .just(remote())
        let detail = try value(interactor.detail(deckId: deckId))
        XCTAssertFalse(interactor.hasDeviceCopy(deckId: deckId))
        XCTAssertEqual(try interactor.saveToDevice(detail), .imported(deckId: deckId))
        XCTAssertTrue(interactor.hasDeviceCopy(deckId: deckId))
        let stored = try XCTUnwrap(repository.desk(withId: deckId))
        XCTAssertEqual(stored.cards.map(\.id), ["aaaaaaaa-0000-4000-8000-000000000001", "aaaaaaaa-0000-4000-8000-000000000002"])
        XCTAssertEqual(stored.cards.first?.frontExtraText, "いぬ", "The reading goes under the Japanese front")
        XCTAssertEqual(try interactor.saveToDevice(detail), .alreadyPresent(deckId: deckId), "Saving twice never duplicates the deck")
        XCTAssertEqual(repository.getAll().count, 1)
    }

    func test_directionIsReadFromTheFirstCard() {
        func cards(_ front: String, _ back: String) -> [ServerDeckCard] { [ServerDeckCard(id: "i", front: front, back: back, reading: "")] }
        XCTAssertEqual(CardLibraryServerInteractor.direction(of: cards("犬", "chó")), .japaneseToVietnamese)
        XCTAssertEqual(CardLibraryServerInteractor.direction(of: cards("chó", "犬")), .vietnameseToJapanese)
        XCTAssertEqual(CardLibraryServerInteractor.direction(of: cards("hello", "xin chào")), .japaneseToVietnamese, "No Japanese at all: the default")
        XCTAssertEqual(CardLibraryServerInteractor.direction(of: []), .japaneseToVietnamese)
    }
}
