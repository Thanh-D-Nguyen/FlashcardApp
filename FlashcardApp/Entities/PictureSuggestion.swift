//
//  PictureSuggestion.swift
//  FlashcardApp
//
//  A picture offered by `POST /api/media/search-images`: a signed selection handle, the https address of the
//  picture and the credit its licence asks for (author, source page, licence). Nothing is invented: a result
//  without an author, source page or licence is dropped, as the website does.
//

import Foundation

struct ImageAttribution: Codable, Equatable {
    /// Provider name as reported by the search service (for example "unsplash").
    let source: String
    /// Where the stored copy was downloaded from.
    let imageURL: String
    /// Credit fields are optional only so records written before they existed still decode.
    var sourceURL: String?
    var author: String?
    var authorURL: String?
    var license: String?
    var licenseURL: String?
    /// The server asset created when the learner chose this picture; lets the deck be saved to the account without uploading it again.
    var assetId: String?

    /// "Photo by Ana Lee · unsplash · Unsplash License", the line shown wherever the picture is shown.
    var creditLine: String {
        let by = author.flatMap { $0.isEmpty ? nil : String(format: NSLocalizedString("Photo by %@", comment: "Picture credit"), $0) }
        return [by, source.isEmpty ? nil : source, license].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The page the credit links to: the author's, else the picture's own page. Always https.
    var creditURL: URL? {
        [authorURL, sourceURL].compactMap { $0 }.compactMap { URL(string: $0) }
            .first { $0.scheme?.lowercased() == "https" && $0.host?.isEmpty == false }
    }
}

struct PictureSuggestion: Equatable {
    /// The signed selection handle; valid for 15 minutes and only for the account that searched.
    let handle: String
    let imageURL: URL
    private(set) var attribution: ImageAttribution

    var source: String { attribution.source }

    /// The same picture once the server registered the choice and returned its asset.
    func registered(assetId: String) -> PictureSuggestion {
        var copy = self
        copy.attribution.assetId = assetId
        return copy
    }

    /// `nil` unless the picture address is https (a card picture is only ever downloaded over a secure connection)
    /// and every credit field the licence needs is present.
    init?(_ dto: BJTImageResultDTO) {
        func secure(_ raw: String?) -> String? {
            guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host?.isEmpty == false else { return nil }
            return raw
        }
        let provider = dto.provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = dto.author.trimmingCharacters(in: .whitespacesAndNewlines)
        let license = dto.license.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dto.handle.isEmpty, !provider.isEmpty, !author.isEmpty, !license.isEmpty,
              let image = secure(dto.url), let url = URL(string: image), let sourceURL = secure(dto.sourceUrl) else { return nil }
        handle = dto.handle
        imageURL = url
        attribution = ImageAttribution(source: provider, imageURL: image, sourceURL: sourceURL, author: author,
                                       authorURL: secure(dto.authorUrl), license: license, licenseURL: secure(dto.licenseUrl))
    }
}
