//
//  MainScheduleSubscribler.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/08.
//

import UIKit
import RxSwift
import RxCocoa

protocol MainScheduleSubcriblerProtocol { }

extension ObservableType {
    var main: Observable<Element> {
        return self.observe(on: MainScheduler.instance)
    }
}

extension MainScheduleSubcriblerProtocol where Self: BaseVC {
    func subscribe<T>(_ subject: PublishRelay<T>, _ consumer: @escaping (T) -> Void) {
        subject.main.subscribe(onNext: { value in
            consumer(value)
        }).disposed(by: disposeBag)
    }
    
    func subscribe<T>(_ subject: BehaviorRelay<T>, _ consumer: @escaping (T) -> Void) {
        subject.main.subscribe(onNext: { value in
            consumer(value)
        }).disposed(by: disposeBag)
    }
}

extension BaseVC: MainScheduleSubcriblerProtocol {}
