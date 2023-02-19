//
//  BaseViewControler.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/08.
//

import UIKit
import RxCocoa
import RxSwift

protocol BaseViewControllerProtocol: AnyObject {
    func setupUI()
    func subscribe()
}

typealias BaseViewController = BaseVC & BaseViewControllerProtocol & ViewInterface

class BaseVC: UIViewController {
    let disposeBag = DisposeBag()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        Constants.currentBarStyle
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
//        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self is HomeViewController {
            Constants.currentBarStyle = .lightContent
        } else {
            Constants.currentBarStyle = .darkContent
        }
        UIView.animate(withDuration: 0.3) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: self)
    }
    
    private func setupUI() {
        fatalError("\(#function) Must implemented in subclass")
    }
    
    private func subscribe() {
        fatalError("\(#function) Must implemented in subclass")
    }
    
    @objc private func appMovedToBackground() { }
    
    @objc private func appMovedToForeground() { }
}
