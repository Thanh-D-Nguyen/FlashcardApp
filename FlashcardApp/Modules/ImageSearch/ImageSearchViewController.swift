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
    @IBOutlet private weak var segmentedControl: RESegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }
    
    func setupUI() {
        let titles = ["Pixabay", "Flickr"]
        var segmentItems: [SegmentModel] {
            return titles.map({ SegmentModel(title: $0) })
        }
        let preset = BootstapPreset(backgroundColor: AppColor.whiteSmoke!, selectedBackgroundColor: AppColor.peach!)
        segmentedControl.configure(segmentItems: segmentItems, preset: preset)
    }
    
    func subscribe() {
        
    }
}
