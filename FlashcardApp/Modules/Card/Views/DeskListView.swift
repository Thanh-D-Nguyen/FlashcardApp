//
//  DeskListView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/25.
//

import UIKit

class DeskListView: UIView {
    @IBOutlet private weak var deskTableView: UITableView!
    
    private var desks: [DeskEntity] = []
    
    var didSelectDeskAtIndex: ((Int) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        instantiate()
        deskTableView.registerNib(cellClass: DeskListCell.self)
        
        let tapGuestute = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        tapGuestute.cancelsTouchesInView = false
        addGestureRecognizer(tapGuestute)
    }
    
    func updateDesks(_ desks: [DeskEntity]) {
        self.desks = desks
        deskTableView.reloadData()
    }
    
    @objc
    private func dismiss(_ sender: UITapGestureRecognizer) {
        self.removeFromSuperview()
    }
}

extension DeskListView: NibInstantiate {}

extension DeskListView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return desks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: DeskListCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
        cell.updateInfo(desks[indexPath.row])
        return cell
    }
}

extension DeskListView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.didSelectDeskAtIndex?(indexPath.row)
    }
}
