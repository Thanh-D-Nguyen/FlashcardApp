//
//  DictionaryViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

final class DictionaryViewController: BaseViewController {
    var presenter: DictionaryPresenterInterface!
    @IBOutlet private weak var welcomeContainerView: UIView!
    @IBOutlet private weak var groupItemsView: UIView!
    
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var segmentedControl: RESegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {
        let searchRightView = SearchRightView(frame: .zero)
        self.searchTextField.rightView = searchRightView
        self.searchTextField.rightViewMode = .always
        let searchLeftView = UIImageView(image: UIImage(resource: ImageResource.icSearch))
        self.searchTextField.leftView = searchLeftView
        self.searchTextField.leftViewMode = .always
        self.searchTextField.leftViewRect(forBounds: CGRect(origin: .zero, size: .init(width: 65, height: 44)))

        let titles = DictionarySearchType.all()
        var segmentItems: [SegmentModel] {
            return titles.map({ SegmentModel(title: $0.uppercased()) })
        }
        let preset = FlashCardPreset(backgroundColor: AppColors.primary, selectedBackgroundColor: AppColors.background, textColor: AppColors.background, selectedTextColor: AppColors.primary, cornerRadius: 4.0)
        segmentedControl.configure(segmentItems: segmentItems, preset: preset)
    }

    func subscribe() {
        subscribe(presenter.createdPageControllerRelay, { [weak self] controller in
            guard let self else { return }
            self.updatePageController(controller)
        })
    }
    
    private func updatePageController(_ controller: UIViewController) {
        groupItemsView.addSubview(controller.view)
        controller.didMove(toParent: self)
        self.addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        groupItemsView.topAnchor.constraint(equalTo: controller.view.topAnchor).isActive = true
        groupItemsView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor).isActive = true
        groupItemsView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor).isActive = true
        groupItemsView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor).isActive = true
    }
}

extension DictionaryViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        true
    }
}

/// Actions
extension DictionaryViewController {
    @IBAction private func segmentDictionatyValueChanged() {
        presenter.searchText(searchTextField.text, withType: segmentedControl.selectedSegmentIndex)
    }
    
    @IBAction private func textFieldValueChaged(_ textField: UITextField) {
        presenter.searchText(textField.text, withType: segmentedControl.selectedSegmentIndex)
    }
}

