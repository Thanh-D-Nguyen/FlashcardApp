//
//  SettingPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import Foundation
import RxRelay

enum SettingTableCell: Int, CaseIterable {
    case account = 0
    case language
    case darkmode
    case notification
    case sounds
    case privacy
    
    var text: String {
        switch self {
            case .account:
                return NSLocalizedString("Account", comment: "")
            case .language:
                return NSLocalizedString("Language", comment: "")
            case .darkmode:
                return NSLocalizedString("Dark Mode", comment: "")
            case .notification:
                return NSLocalizedString("Notification", comment: "")
            case .sounds:
                return NSLocalizedString("Sounds", comment: "")
            case .privacy:
                return NSLocalizedString("Privacy", comment: "")
        }
    }
    
    var subText: String {
        if self == .language {
            return NSLocalizedString("English", comment: "")
        }
        return ""
    }
    
    var imageNamed: String {
        switch self {
            case .account:
                return ""
            case .language:
                return "character.book.closed"
            case .darkmode:
                return "moon"
            case .notification:
                return "message.badge"
            case .sounds:
                return "speaker.wave.2"
            case .privacy:
                return "hand.raised"
        }
    }
}

protocol SettingPresenterInterface: AnyObject {
    var settingDataRelay: BehaviorRelay<[SettingTableCell]> { get }
    
    func viewDidLoad()
}

class SettingPresenter {
    private let interactor: SettingInteractorInterface
    private let wireframe: SettingWireframeInterface
    
    let settingDataRelay = BehaviorRelay<[SettingTableCell]>(value: [])

    init(interactor: SettingInteractorInterface, 
        wireframe: SettingWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SettingPresenter: SettingPresenterInterface {
    func viewDidLoad() {
        let settingData = SettingTableCell.allCases
        settingDataRelay.accept(settingData)
    }
}
