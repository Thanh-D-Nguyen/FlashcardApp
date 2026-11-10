import UIKit

/// One article as a scrolling page. The reading part is built once; the vocabulary and the quiz change as the learner uses
/// them, so only that section is redrawn and the scroll position stays where it is.
final class MagazineArticleViewController: BaseVC, MagazineArticleViewInterface {
    var presenter: MagazineArticlePresenterInterface!

    private let scrollView = UIScrollView()
    private let page = UIStackView()
    private let stateView = StateView()
    private let readingHolder = UIStackView()
    private let vocabularyHolder = UIStackView()
    private let quizHolder = UIStackView()
    private let noteLabel = UILabel()

    private var shownReading: (header: MagazineArticleState.Header, blocks: [MagazineArticle.Block])?
    private var shownVocabulary: MagazineArticleState.Vocabulary?
    private var shownQuiz: MagazineArticleState.Quiz?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonDisplayMode = .minimal

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "magazine_article"
        page.axis = .vertical
        page.spacing = Design.Spacing.xl
        page.translatesAutoresizingMaskIntoConstraints = false
        for holder in [readingHolder, vocabularyHolder, quizHolder] {
            holder.axis = .vertical
            holder.spacing = Design.Spacing.m
        }
        readingHolder.spacing = Design.Spacing.l
        noteLabel.apply(.metadata)
        noteLabel.textAlignment = .center
        [readingHolder, vocabularyHolder, quizHolder, noteLabel].forEach(page.addArrangedSubview)
        scrollView.addSubview(page)
        view.addSubview(scrollView)
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true
        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            page.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.s),
            page.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xxl),
            page.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            page.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: MagazineArticleViewInterface

    func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    func render(_ state: MagazineArticleViewState) {
        loadViewIfNeeded()
        switch state {
        case .loading(let message):
            scrollView.isHidden = true
            stateView.isHidden = false
            stateView.configure(.loading(message))
        case .failed(let title, let message):
            scrollView.isHidden = true
            stateView.isHidden = false
            stateView.configure(.error(message: "\(title)\n\(message)", retryTitle: NSLocalizedString("Try again", comment: ""))) { [weak self] in
                self?.presenter.retry()
            }
        case .article(let article):
            stateView.isHidden = true
            scrollView.isHidden = false
            renderReading(article)
            renderVocabulary(article)
            renderQuiz(article)
            noteLabel.text = article.note
            noteLabel.isHidden = article.note == nil
            #if DEBUG
            scrollForLaunchArgument()
            #endif
        }
    }

    private func renderReading(_ article: MagazineArticleState) {
        guard shownReading?.header != article.header || shownReading?.blocks != article.blocks else { return }
        shownReading = (article.header, article.blocks)
        readingHolder.arrangedSubviews.forEach { $0.removeFromSuperview() }
        readingHolder.addArrangedSubview(MagazineArticleViews.header(article.header))
        MagazineArticleViews.blocks(article.blocks, kind: article.header.kind).forEach(readingHolder.addArrangedSubview)
        scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: false)
        UIAccessibility.post(notification: .screenChanged, argument: readingHolder.arrangedSubviews.first)
    }

    private func renderVocabulary(_ article: MagazineArticleState) {
        guard shownVocabulary != article.vocabulary || vocabularyHolder.arrangedSubviews.isEmpty != (article.vocabulary == nil) else { return }
        shownVocabulary = article.vocabulary
        vocabularyHolder.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let vocabulary = article.vocabulary else { return }
        let actions = MagazineArticleViews.VocabularyActions(
            toggle: { [weak self] in self?.presenter.toggleWord(id: $0) },
            chooseDeck: { [weak self] in self?.presenter.chooseDeck() },
            primary: { [weak self] in self?.presenter.saveWords() })
        vocabularyHolder.addArrangedSubview(MagazineArticleViews.vocabulary(vocabulary, kind: article.header.kind, actions: actions))
    }

    private func renderQuiz(_ article: MagazineArticleState) {
        guard shownQuiz != article.quiz || quizHolder.arrangedSubviews.isEmpty != (article.quiz == nil) else { return }
        let previousProgress: String? = { if case .question(let question)? = shownQuiz { return question.progress } else { return nil } }()
        shownQuiz = article.quiz
        quizHolder.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let quiz = article.quiz, let title = article.quizTitle else { return }
        let actions = MagazineArticleViews.QuizActions(
            select: { [weak self] in self?.presenter.selectOption($0) },
            next: { [weak self] in self?.presenter.nextQuestion() },
            restart: { [weak self] in self?.presenter.restartQuiz() })
        quizHolder.addArrangedSubview(MagazineArticleViews.quiz(title: title, quiz, kind: article.header.kind, actions: actions))
        // A new question or the result takes the place of the old one: keep it in view and tell VoiceOver where to start.
        if case .question(let question) = quiz, question.feedbackTitle == nil, previousProgress != nil, previousProgress != question.progress {
            view.layoutIfNeeded()
            scrollView.scrollRectToVisible(quizHolder.frame.insetBy(dx: 0, dy: -Design.Spacing.l), animated: !UIAccessibility.isReduceMotionEnabled)
            UIAccessibility.post(notification: .layoutChanged, argument: quizHolder.arrangedSubviews.first)
        } else if case .result = quiz {
            UIAccessibility.post(notification: .layoutChanged, argument: quizHolder.arrangedSubviews.first)
        }
    }

    #if DEBUG
    private var scrolledForLaunchArgument = false

    /// `-ArticleScrollTo <vocabulary|quiz>` scrolls to that section once, for screenshots (the simulator tools cannot swipe).
    private func scrollForLaunchArgument() {
        let arguments = ProcessInfo.processInfo.arguments
        guard !scrolledForLaunchArgument, let index = arguments.firstIndex(of: "-ArticleScrollTo"), index + 1 < arguments.count else { return }
        scrolledForLaunchArgument = true
        let target = arguments[index + 1] == "quiz" ? quizHolder : vocabularyHolder
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.layoutIfNeeded()
            self.scrollView.setContentOffset(CGPoint(x: 0, y: max(0, target.frame.minY - 80)), animated: false)
        }
    }
    #endif
}
