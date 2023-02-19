//
//  SlideShowViewController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//

import UIKit

class SlideShowViewController: BaseViewController {
    
    var presenter: SlideShowPresenterInterface!
    
    @IBOutlet weak private var containerView: UIView!
    @IBOutlet weak private var pageControl: UIPageControl!
    
    private var pageView: UIPageViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }
    
    func setupUI() {
        pageView = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageView.dataSource = self
        pageView.delegate = self
        addChild(pageView)
        containerView.addSubview(pageView.view)
        pageView.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageView.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            pageView.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            pageView.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pageView.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        pageView.didMove(toParent: self)
        pageView.setViewControllers([presenter.pageBefore(nil)!], direction: .forward, animated: false)
        updatePageControlUI(currentPageIndex: 0)
    }
    
    func subscribe() { }
    
    private func updatePageControlUI(currentPageIndex: Int) {
        (0 ..< pageControl.numberOfPages).forEach { index in
            let currentPageControl = UIImage(named: "currentPageControl")
            let otherPageControl = UIImage(named: "dot")
            let pageIcon = index == currentPageIndex ? currentPageControl : otherPageControl
            pageControl.setIndicatorImage(pageIcon, forPage: index)
        }
    }
    
    @IBAction
    private func getStartedAction() {
        presenter.getStartedAction()
    }

}

extension SlideShowViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        return presenter.pageBefore(viewController)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        return presenter.pageAfter(viewController)
    }
}

extension SlideShowViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard let selectedVC = pageViewController.viewControllers?.first as? SlideItemViewController else { return }
        pageControl.currentPage = selectedVC.index ?? 0
        updatePageControlUI(currentPageIndex: selectedVC.index ?? 0)
    }
}
