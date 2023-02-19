//
//  SlideItemViewController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//

import UIKit

class SlideItemViewController: UIViewController {
    
    @IBOutlet weak private var imageView: UIImageView!
    @IBOutlet weak private var titleLabel: UILabel!
    
    private var welcomeEntity: WelcomeEntity?
    
    var index: Int? {
        return welcomeEntity?.index
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        guard let entity = welcomeEntity else { return }
        imageView.image = UIImage(named: entity.imageName)
        titleLabel.text = entity.title
    }
    
    func updatePageItem(_ entity: WelcomeEntity) {
        self.welcomeEntity = entity
    }
}
