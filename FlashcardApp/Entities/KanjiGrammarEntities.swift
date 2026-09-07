//
//  KanjiGrammarEntities.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Foundation

class KanjiEntity {
    var id: String = ""
    var character: String = ""
    var meaningVi: String = ""
    var onyomi: String = ""
    var kunyomi: String = ""
    var strokeCount: Int = 0
    var level: String = ""
    var frequency: Int = 0
    var detail: String = ""
    var tip: String = ""
    var imagePath: String = ""
}

class GrammarEntity {
    var id: String = ""
    var pattern: String = ""
    var meaningVi: String = ""
    var jlptLevel: String = ""
    var category: String = ""
    var status: String = ""
}
