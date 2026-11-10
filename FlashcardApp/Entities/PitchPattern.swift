//
//  PitchPattern.swift
//  FlashcardApp
//
//  Pitch accent of a word as the backend stores it: one H/L letter per mora, and after a dash the pitch of a following
//  particle ("LHL-L"). It is drawn only when the data fits the word (same rule as the website); otherwise the screen
//  shows no pitch rather than a guessed one.
//

import Foundation

struct PitchPattern: Equatable {
    enum Level: Equatable { case high, low }

    enum Kind: Equatable {
        /// 平板: rises after the first mora and never drops.
        case heiban
        /// 頭高: drops right after the first mora.
        case atamadaka
        /// 中高: drops inside the word.
        case nakadaka
        /// 尾高: stays high to the end and drops on the particle.
        case odaka
    }

    let morae: [String]
    let levels: [Level]
    /// Pitch of a particle that follows the word, when the data says so.
    let particle: Level?

    var text: String { morae.joined() }

    /// Accent nucleus: the number of the mora after which the pitch falls; 0 when it never falls.
    var number: Int {
        for index in stride(from: levels.count - 1, through: 0, by: -1) where levels[index] == .high {
            let next = index + 1 < levels.count ? levels[index + 1] : particle
            if next == .low { return index + 1 }
        }
        return 0
    }

    var kind: Kind {
        switch number {
        case 0: return .heiban
        case 1: return .atamadaka
        case levels.count: return .odaka
        default: return .nakadaka
        }
    }

    init?(accent: String?, morae: [String]) {
        guard let accent, !morae.isEmpty else { return nil }
        let groups = accent.uppercased().split(separator: "-", omittingEmptySubsequences: false)
            .map { $0.filter { $0 == "H" || $0 == "L" } }
        guard let index = groups.firstIndex(where: { $0.count == morae.count }) else { return nil }
        self.morae = morae
        levels = groups[index].map { $0 == "H" ? .high : .low }
        // The letter after the matching group is the particle's pitch when it is a single H or L.
        if index + 1 < groups.count, groups[index + 1].count == 1 {
            particle = groups[index + 1].first == "H" ? .high : .low
        } else {
            particle = nil
        }
    }

    static func patterns(from entries: [BJTLexemeDetailDTO.Pronunciation]) -> [PitchPattern] {
        entries.compactMap { entry in
            let morae = entry.morae.isEmpty ? morae(ofKana: entry.kana ?? "") : entry.morae
            return PitchPattern(accent: entry.accent, morae: morae)
        }
    }

    /// Splits kana into morae: a small ゃ/ゅ/ょ (or ぁぃぅぇぉ) joins the kana before it; っ, ん and ー count as a mora each.
    static func morae(ofKana kana: String) -> [String] {
        let small = Set("ゃゅょぁぃぅぇぉャュョァィゥェォ")
        var result: [String] = []
        for character in kana {
            if small.contains(character), !result.isEmpty {
                result[result.count - 1].append(character)
            } else {
                result.append(String(character))
            }
        }
        return result
    }
}
