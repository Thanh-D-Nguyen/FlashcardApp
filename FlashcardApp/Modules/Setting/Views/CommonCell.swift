//
//  CommonCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import UIKit

class CommonCell: UITableViewCell {
    
    @IBOutlet private weak var configImageView: UIImageView!
    @IBOutlet private weak var configTitleLabel: UILabel!
    @IBOutlet private weak var subTitleLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    func updateCell(_ config: SettingTableCell) {
        subTitleLabel.text = config.subText
        configTitleLabel.text = config.text
        configImageView.image = UIImage(systemName: config.imageNamed)
    }
    
}
