//
//  DeskListCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/05/12.
//

import UIKit

class DeskListCell: UICollectionViewCell {

    @IBOutlet private var deskTitle: UILabel!
    @IBOutlet private var deskSubTitle: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func updateDesk(_ desk: DeskEntity) {
        deskTitle.text = desk.name
        deskSubTitle.text = desk.description
    }

}
