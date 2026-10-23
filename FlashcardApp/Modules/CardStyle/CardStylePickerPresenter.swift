import Foundation

/// One choice in the picker: a catalogue style, or `nil` for the app's own adaptive card.
struct CardStyleOption: Equatable {
    let style: CardStyle?
    var slug: String? { style?.slug }

    var title: String { style?.name ?? NSLocalizedString("Default", comment: "Card style: the app's own card") }
    var summary: String {
        style?.summary ?? NSLocalizedString("Follows Light and Dark appearance.", comment: "Card style description")
    }
}

struct CardStylePickerState: Equatable {
    let options: [CardStyleOption]
    let selectedSlug: String?
}

protocol CardStylePickerViewInterface: AnyObject {
    func render(_ state: CardStylePickerState)
}

protocol CardStylePickerPresenterInterface: AnyObject {
    func viewDidLoad()
    func select(_ option: CardStyleOption)
    func close()
}

protocol CardStylePickerWireframeInterface: AnyObject {
    func finish()
}

/// The chosen style is stored right away, so the card behind the sheet shows it and closing needs no confirmation.
final class CardStylePickerPresenter: CardStylePickerPresenterInterface {
    private let preferences: StudyPreferencesInterface
    private let wireframe: CardStylePickerWireframeInterface
    private let onChange: () -> Void
    private var selectedSlug: String?
    weak var view: CardStylePickerViewInterface?

    init(selectedSlug: String?, preferences: StudyPreferencesInterface = UserDefaultsStudyPreferences.shared,
         wireframe: CardStylePickerWireframeInterface, onChange: @escaping () -> Void) {
        // A slug this version does not know is shown as the default card, as the study screen does.
        self.selectedSlug = CardStyle.style(forSlug: selectedSlug)?.slug
        self.preferences = preferences
        self.wireframe = wireframe
        self.onChange = onChange
    }

    func viewDidLoad() { publish() }

    func select(_ option: CardStyleOption) {
        guard option.slug != selectedSlug else { return }
        selectedSlug = option.slug
        preferences.cardStyleSlug = option.slug
        publish()
        onChange()
    }

    func close() { wireframe.finish() }

    private func publish() {
        let options = [CardStyleOption(style: nil)] + CardStyle.catalog.map { CardStyleOption(style: $0) }
        view?.render(CardStylePickerState(options: options, selectedSlug: selectedSlug))
    }
}
