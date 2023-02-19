//
//  HomeSubSectionCell.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/15.
//

import UIKit

class HomeSubSectionCell: UITableViewCell {
    
    @IBOutlet weak private var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    func updateTitle(_ section: HomeSectionType) {
        titleLabel.text = section.titleText
    }
    
}
