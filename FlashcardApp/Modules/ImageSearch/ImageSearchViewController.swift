//
//  ImageSearchViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//  
//

import UIKit

final class ImageSearchViewController: BaseViewController {
    var presenter: ImageSearchPresenterInterface!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }
    
    func setupUI() {
        
    }
    
    func subscribe() {
        
    }
}
