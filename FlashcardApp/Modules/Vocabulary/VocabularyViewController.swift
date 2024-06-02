//
//  VocabularyViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/10/01.
//  
//

import UIKit

final class VocabularyViewController: BaseViewController {
    var presenter: VocabularyPresenterInterface!

    @IBOutlet private weak var vocalTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {
        vocalTableView.registerNib(cellClass: SynonymsAntonymsCell.self)
        vocalTableView.registerNib(cellClass: MeanCell.self)
        vocalTableView.registerNib(cellClass: SentenceCell.self)
        vocalTableView.registerNib(cellClass: RelateCell.self)
    }

    func subscribe() {

    }
}

extension VocabularyViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return VocabularySections.sectionCount
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = VocabularySections(rawValue: indexPath.section) else { return UITableViewCell() }
        switch sectionType {
            case .mean:
                let cell: MeanCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
                return cell
            case .synonyms,.antonyms:
                let cell: SynonymsAntonymsCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
                return cell
            case .sentences:
                let cell: SentenceCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
                return cell
            case .relate:
                let cell: RelateCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
                return cell
        }
    }
}

extension VocabularyViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = VocabularySections(rawValue: section) else { return nil }
        return sectionType.description
    }
}
