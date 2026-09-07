//
//  TitleOnlyCell.swift
//  FlashcardApp
//
//  Stub for build compatibility.
//

import UIKit

class TitleOnlyCell: UITableViewCell {
    @IBOutlet private weak var titleLabel: UILabel?

    func updateTitle(_ title: String) {
        titleLabel?.text = title
    }
}
