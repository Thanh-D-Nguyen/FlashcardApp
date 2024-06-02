//
//  WelcomeEntity.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//

import Foundation

struct WelcomeEntity {
    var imageName: String
    var title: String
    var index: Int
    init(index: Int) {
        self.index = index
        imageName =  "Welcome\(index + 1)"
        title = ""
        if index == 0 {
            title = NSLocalizedString("Master Japanese with Flashcards", comment: "")
        } else if index == 1 {
            title = NSLocalizedString("Test Your Knowledge with Quizzes", comment: "")
        } else if index == 2 {
            title = NSLocalizedString("Expand Your Vocabulary with the Dictionary", comment: "")
        }
    }
    static let pageCount = 3
}
