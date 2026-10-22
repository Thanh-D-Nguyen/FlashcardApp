//
//  PictureSuggestion.swift
//  FlashcardApp
//
//  A picture offered by `POST /api/media/search-images`. Only what the endpoint reports is kept: an id, a
//  thumbnail, the full-size address and the provider name. The contract has no photographer or licence
//  fields, so none are invented.
//

import Foundation

struct ImageAttribution: Codable, Equatable {
    /// Provider name as reported by the search service (for example "unsplash").
    let source: String
    let sourceID: String
    /// Where the stored copy was downloaded from.
    let imageURL: String
}

struct PictureSuggestion: Equatable {
    let id: String
    let thumbnailURL: URL
    let imageURL: URL
    let source: String

    var attribution: ImageAttribution { ImageAttribution(source: source, sourceID: id, imageURL: imageURL.absoluteString) }

    /// `nil` unless both addresses are https: a card picture is only ever downloaded over a secure connection.
    init?(_ dto: BJTImageResultDTO) {
        guard !dto.id.isEmpty,
              let thumbnail = URL(string: dto.thumbUrl), thumbnail.scheme?.lowercased() == "https", thumbnail.host?.isEmpty == false,
              let image = URL(string: dto.fullUrl), image.scheme?.lowercased() == "https", image.host?.isEmpty == false else { return nil }
        id = dto.id
        thumbnailURL = thumbnail
        imageURL = image
        source = dto.source.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
