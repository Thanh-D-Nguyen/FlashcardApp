//
//  BulkDeckImport.swift
//  FlashcardApp
//
//  Parser for pasted card lists. Same grammar as the website composer
//  (`bulk-deck-import-parse.ts`): one card per line, `front<TAB>back[<TAB>imageUrl]` or
//  `front|back[|imageUrl]`, at most 200 lines.
//

import Foundation

enum BulkDeckImport {
    static let maximumRows = 200

    struct Row: Equatable {
        var front: String
        var back: String
        var imageUrl: String?
    }

    enum Failure: Error, Equatable {
        case invalidLine(Int)
        case invalidImageUrl(line: Int)
        case tooManyRows
    }

    static func parse(_ text: String) -> Result<[Row], Failure> {
        let lines = text.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count <= maximumRows else { return .failure(.tooManyRows) }
        var rows: [Row] = []
        for (offset, line) in lines.enumerated() {
            let number = offset + 1
            var parts = line.components(separatedBy: "\t")
            if parts.count < 2 {
                parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            }
            guard parts.count >= 2 else { return .failure(.invalidLine(number)) }
            let front = parts[0].trimmingCharacters(in: .whitespaces)
            let back = parts[1].trimmingCharacters(in: .whitespaces)
            guard !front.isEmpty, !back.isEmpty else { return .failure(.invalidLine(number)) }
            var image: String?
            if parts.count > 2 {
                let candidate = parts[2].trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty {
                    // The Info.plist allows only https (plus loopback http), so anything else would never load.
                    guard case .remote(let url) = CardImageReference(candidate), url.scheme?.lowercased() == "https" else {
                        return .failure(.invalidImageUrl(line: number))
                    }
                    image = url.absoluteString
                }
            }
            rows.append(Row(front: front, back: back, imageUrl: image))
        }
        return .success(rows)
    }
}
