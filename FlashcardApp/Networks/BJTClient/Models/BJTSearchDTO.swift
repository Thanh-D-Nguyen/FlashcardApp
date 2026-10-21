import Foundation

struct BJTSearchResultDTO: Codable, Equatable {
    let id: String
    let kind: String
    let title: String
    let description: String?
    let reading: String?
    let jlptLevel: String?
}
