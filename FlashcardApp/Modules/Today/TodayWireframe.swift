import UIKit

protocol TodayWireframeInterface: AnyObject {
    func showStudy(deckId: String, cardIDs: [String]?)
    /// The whole flow for a new deck (type it or generate it); `onFinish` runs when a deck may have been made or the flow was left.
    func showCreateDeck(onFinish: @escaping () -> Void)
    func showDeckChooser(_ choices: [TodayDeckChoice], selectedID: String?, onSelect: @escaping (String) -> Void)
    func showBudgetChooser(current: Int, onSelect: @escaping (Int) -> Void)
    func showLevels()
    func showScenarios()
    /// One structured lesson, opened from the lesson slot.
    func showLesson(slug: String, title: String)
    /// One Daily Radar card, read in the app.
    func showRadarCard(_ item: DailyRadarItem)
    func showLifeLesson(cityID: String, lesson: LifeLesson)
    func showCityChooser(selectedID: String, onSelect: @escaping (String) -> Void)
    /// The system page of this app's settings, where the learner can allow the location again.
    func openAppSettings()
}

final class TodayWireframe: BaseWireframe<TodayViewController> {
    init() {
        let controller = TodayViewController()
        super.init(viewController: controller)
        controller.title = MainTabbarName.today.title
        controller.tabBarItem = MainTabbarName.today.tabBarItem
        let presenter = TodayPresenter(interactor: TodayInteractor(), wireframe: self, life: TodayLifeHubLoader(weather: TodayLifeLoader()),
                                    lessons: TodayLessonSlotProvider(), streak: TodayStreakLoader(),
                                    radar: TodayRadarLoader())
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension TodayWireframe: TodayWireframeInterface {
    func showRadarCard(_ item: DailyRadarItem) {
        navigationController?.pushViewController(DailyRadarCardViewController(item: item), animated: true)
    }

    func showStudy(deckId: String, cardIDs: [String]?) {
        navigationController?.pushWireframe(CardStudyWireframe(deckId: deckId, cardIDs: cardIDs))
    }

    func showCreateDeck(onFinish: @escaping () -> Void) {
        NewDeckFlow.presentCompleteFlow(from: viewController, onFinish: onFinish)
    }

    func showDeckChooser(_ choices: [TodayDeckChoice], selectedID: String?, onSelect: @escaping (String) -> Void) {
        let sheet = UIAlertController(title: NSLocalizedString("Study deck", comment: ""), message: nil, preferredStyle: .actionSheet)
        for choice in choices {
            let cards = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), choice.cardCount)
            let mark = choice.id == selectedID ? "✓ " : ""
            sheet.addAction(UIAlertAction(title: "\(mark)\(choice.name) · \(cards)", style: .default) { _ in onSelect(choice.id) })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(sheet)
    }

    func showBudgetChooser(current: Int, onSelect: @escaping (Int) -> Void) {
        let sheet = UIAlertController(title: NSLocalizedString("Session length", comment: ""),
                                      message: NSLocalizedString("Time is an estimate, not a countdown.", comment: ""), preferredStyle: .actionSheet)
        for minutes in TodayBudget.allowedMinutes {
            let mark = minutes == current ? "✓ " : ""
            sheet.addAction(UIAlertAction(title: mark + String.localizedStringWithFormat(NSLocalizedString("%lld minutes", comment: ""), minutes),
                                          style: .default) { _ in onSelect(minutes) })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(sheet)
    }

    func showLevels() {
        navigationController?.pushWireframe(HomeWireframe())
    }

    func showScenarios() {
        navigationController?.pushWireframe(ScenarioListWireframe())
    }

    func showLesson(slug: String, title: String) {
        navigationController?.pushWireframe(LessonReaderWireframe(slug: slug, title: title))
    }

    func showLifeLesson(cityID: String, lesson: LifeLesson) {
        navigationController?.pushWireframe(LifeLessonWireframe(cityID: cityID, lesson: lesson))
    }

    func showCityChooser(selectedID: String, onSelect: @escaping (String) -> Void) {
        let language = AppLanguage.current
        let sheet = UIAlertController(title: NSLocalizedString("Today's weather", comment: "City chooser title"),
                                      message: NSLocalizedString("Choose a city. Your location is never used.", comment: ""), preferredStyle: .actionSheet)
        for city in LifeCity.all {
            let mark = city.id == selectedID ? "✓ " : ""
            sheet.addAction(UIAlertAction(title: mark + city.displayName(language), style: .default) { _ in onSelect(city.id) })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(sheet)
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func present(_ sheet: UIAlertController) {
        // On iPhone it is the system's own sheet; only a wide screen needs an anchor.
        if viewController.traitCollection.userInterfaceIdiom == .pad {
            sheet.popoverPresentationController?.sourceView = viewController.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
        }
        viewController.present(sheet, animated: true)
    }
}
