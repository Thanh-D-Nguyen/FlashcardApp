//
//  DeskListCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/25.
//

import UIKit

class DeskListCell: UITableViewCell {
    
    @IBOutlet private weak var deskTitle: UILabel!
    @IBOutlet private weak var deskSubTitle: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func updateInfo(_ desk: DeskEntity) {
        deskTitle.text = desk.name
        deskSubTitle.text = desk.description
    }
    
}
