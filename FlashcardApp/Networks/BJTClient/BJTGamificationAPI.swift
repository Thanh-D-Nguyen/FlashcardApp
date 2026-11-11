import Alamofire
import Foundation
import RxSwift

/// One streak of `GET /api/gamification/streaks`. The server keeps one per configured activity type (production 2026-11-11:
/// `review`, `exercise`, `quiz` and `any`); `lastActiveDate` is a calendar day `yyyy-MM-dd`, absent before the first activity.
struct BJTStreakDTO: Decodable, Equatable {
    let configId: String
    let activityType: String
    let currentStreak: Int
    let longestStreak: Int
    let lastActiveDate: String?
}

struct BJTStreaksDTO: Decodable {
    let streaks: [BJTStreakDTO]
}

/// The activity types `POST /api/gamification/streaks/record` accepts that the app records.
enum StreakActivity: String {
    case review
}

protocol BJTStreakAPIInterface: AnyObject {
    /// Read-only; safe to repeat.
    func streaks() -> Single<[BJTStreakDTO]>
    /// Counts the learner's day for the streaks of `activity` (and the `any` streak). Repeating it on the same day changes nothing on the
    /// server. `timeZone` names the learner's day for servers that accept it; older servers ignore it and use their own clock.
    func recordStreakActivity(_ activity: StreakActivity, timeZone: TimeZone?) -> Single<Void>
}

extension BJTLearnerAPI: BJTStreakAPIInterface {
    private struct NoBody: Encodable {}
    private struct RecordResponse: Decodable { let success: Bool }

    func streaks() -> Single<[BJTStreakDTO]> {
        let response: Single<BJTStreaksDTO> = perform(["gamification", "streaks"], method: .get, body: Optional<NoBody>.none)
        return response.map(\.streaks)
    }

    func recordStreakActivity(_ activity: StreakActivity, timeZone: TimeZone?) -> Single<Void> {
        var query = ["activityType": activity.rawValue]
        // Only an IANA name the server can load; anything else (a fixed "GMT+0700") would be rejected, so the server's own choice is used.
        if let identifier = timeZone?.identifier, TimeZone.knownTimeZoneIdentifiers.contains(identifier) {
            query["timeZone"] = identifier
        }
        let response: Single<RecordResponse> = perform(["gamification", "streaks", "record"], method: .post, body: Optional<NoBody>.none, query: query)
        return response.map { guard $0.success else { throw LearnerAPIError.invalidResponse } }
    }
}
