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
        imageName =  "Variant\(index + 1)"
        title = ""
        if index == 0 {
            title = NSLocalizedString("Hand-pickle high quality snacks.", comment: "")
        } else if index == 1 {
            title = NSLocalizedString("Shop global. Mind-blownly affordable.", comment: "")
        } else if index == 2 {
            title = NSLocalizedString("Deliver on the promise of time.", comment: "")
        }
    }
    static let pageCount = 3
}
