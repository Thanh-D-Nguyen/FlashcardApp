//
//  MailLoginViewController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit
import AuthenticationServices
import RxSwift

/// Sign-in screen. Editorial and flat on the paper background: a small brand seal, a serif headline, two labelled
/// fields and one primary action, with the guest route as a full-width secondary action right under it.
/// The form is content, so it carries no Liquid Glass; the keyboard and system chrome already do.
final class MailLoginViewController: BaseViewController {

    var presenter: MailLoginPresenterInterface!

    private let scrollView = UIScrollView()
    private let emailField = LoginFieldView(title: NSLocalizedString("Email address", comment: ""))
    private let passwordField = LoginFieldView(title: NSLocalizedString("Password", comment: ""))
    private let passwordToggle = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let errorIcon = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
    private let errorLabel = UILabel()
    private lazy var errorRow = UIStackView(arrangedSubviews: [errorIcon, errorLabel])
    private let signInButton = UIButton(type: .system)
    private let googleButton = UIButton(type: .system)
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
    private let appleButtonDark = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
    private lazy var appleButtons = UIStackView(arrangedSubviews: [appleButton, appleButtonDark])
    private lazy var orDivider = Self.makeOrDivider()
    private let continueWithoutLoginButton = UIButton(type: .system)

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MailLoginViewController is built in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self]) { (controller: MailLoginViewController, _) in
            controller.updateAppleButtonAppearance()
        }
        subscribe()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.cancelLogin()
        view.endEditing(true)
        passwordField.textField.text = nil
        setPasswordRevealed(false)
    }

    // MARK: - Setup

    func setupUI() {
        view.backgroundColor = Design.Color.background
        configureFields()
        configureTexts()
        configureButtons()
        configureErrorRow()
        layoutContent()

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        dismissTap.delegate = self
        view.addGestureRecognizer(dismissTap)
    }

    private func configureFields() {
        let email = emailField.textField
        email.keyboardType = .emailAddress
        email.textContentType = .username
        email.returnKeyType = .next
        email.attributedPlaceholder = presenter.mailPlaceHolderAttributedText
        email.accessibilityIdentifier = "website_email"

        let password = passwordField.textField
        password.isSecureTextEntry = true
        password.textContentType = .password
        password.returnKeyType = .go
        password.accessibilityIdentifier = "website_password"

        for field in [email, password] {
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.smartDashesType = .no
            field.smartQuotesType = .no
            field.delegate = self
            field.addTarget(self, action: #selector(inputChanged), for: .editingChanged)
        }

        var toggle = UIButton.Configuration.plain()
        toggle.baseForegroundColor = Design.Color.textSecondary
        toggle.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: Design.Spacing.m, bottom: 0, trailing: Design.Spacing.m)
        passwordToggle.configuration = toggle
        passwordToggle.accessibilityIdentifier = "website_password_toggle"
        passwordToggle.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        passwordField.setAccessory(passwordToggle)
        setPasswordRevealed(false)
    }

    private func configureTexts() {
        titleLabel.apply(.display)
        titleLabel.text = presenter.titleText
        titleLabel.accessibilityTraits = .header
        subtitleLabel.apply(.meaning)
        subtitleLabel.textColor = Design.Color.textSecondary
        subtitleLabel.text = presenter.subtitleText
    }

    private func configureButtons() {
        signInButton.configuration = Self.styled(Design.Button.primary(title: presenter.loginButtonText, traits: traitCollection))
        signInButton.enableAdaptiveCornerStyle()
        signInButton.accessibilityIdentifier = "website_login_button"
        signInButton.addTarget(self, action: #selector(loginWithEmailAction), for: .touchUpInside)

        continueWithoutLoginButton.configuration = Self.styled(Design.Button.secondary(title: NSLocalizedString("Continue without login", comment: ""), traits: traitCollection))
        continueWithoutLoginButton.enableAdaptiveCornerStyle()
        continueWithoutLoginButton.accessibilityIdentifier = "continueWithoutLoginButton"
        continueWithoutLoginButton.addTarget(self, action: #selector(continueWithoutLoginAction), for: .touchUpInside)

        googleButton.configuration = Self.googleConfiguration(title: presenter.googleButtonText, traits: traitCollection)
        googleButton.enableAdaptiveCornerStyle()
        googleButton.accessibilityIdentifier = "google_login_button"
        googleButton.addTarget(self, action: #selector(loginWithGoogleAction), for: .touchUpInside)
        appleButton.accessibilityIdentifier = "apple_login_button"
        appleButton.addTarget(self, action: #selector(loginWithAppleAction), for: .touchUpInside)
        appleButtonDark.accessibilityIdentifier = "apple_login_button"
        appleButtonDark.addTarget(self, action: #selector(loginWithAppleAction), for: .touchUpInside)
        appleButtons.axis = .vertical
        updateAppleButtonAppearance()
        // Without a valid OAuth client for this build, the option is not offered at all.
        googleButton.isHidden = !presenter.isGoogleSignInAvailable

        for button in [signInButton, googleButton, appleButtons, continueWithoutLoginButton] {
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        }
    }

    private func updateAppleButtonAppearance() {
        let radius: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? Design.Radius.control : 26
        appleButton.cornerRadius = radius
        appleButtonDark.cornerRadius = radius
        appleButton.isHidden = traitCollection.userInterfaceStyle == .dark
        appleButtonDark.isHidden = !appleButton.isHidden
    }

    /// Both actions use the same headline weight so the pair reads as one set.
    private static func styled(_ configuration: UIButton.Configuration) -> UIButton.Configuration {
        var configuration = configuration
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline)
            return attributes
        }
        return configuration
    }

    /// Google's light/dark button theme (white or near-black fill, grey outline, standard "G"), in the screen's capsule
    /// shape and Dynamic Type headline so it sits with the other two actions.
    private static func googleConfiguration(title: String, traits: UITraitCollection) -> UIButton.Configuration {
        func color(light: UInt32, dark: UInt32) -> UIColor {
            func rgb(_ value: UInt32) -> UIColor {
                UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                        blue: CGFloat(value & 0xFF) / 255, alpha: 1)
            }
            return UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) }
        }
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = googleLogo()
        configuration.imagePadding = Design.Spacing.m
        configuration.cornerStyle = Design.Button.cornerStyle(for: traits)
        configuration.buttonSize = .large
        configuration.baseForegroundColor = color(light: 0x1F1F1F, dark: 0xE3E3E3)
        configuration.background.backgroundColor = color(light: 0xFFFFFF, dark: 0x131314)
        configuration.background.strokeColor = color(light: 0x747775, dark: 0x8E918F)
        configuration.background.strokeWidth = 1
        return styled(configuration)
    }

    private static func googleLogo() -> UIImage? {
        guard let logo = UIImage(named: "Google Logo") else { return nil }
        let size = CGSize(width: 20, height: 20)
        return UIGraphicsImageRenderer(size: size).image { _ in logo.draw(in: CGRect(origin: .zero, size: size)) }
            .withRenderingMode(.alwaysOriginal)
    }

    private static func makeOrDivider() -> UIView {
        func line() -> UIView {
            let line = UIView()
            line.backgroundColor = Design.Color.separator
            line.heightAnchor.constraint(equalToConstant: 1).isActive = true
            return line
        }
        let label = UILabel()
        label.apply(.metadata)
        label.textColor = Design.Color.textSecondary
        label.text = NSLocalizedString("or", comment: "Divider between email sign-in and Google sign-in")
        label.isAccessibilityElement = false
        let row = UIStackView(arrangedSubviews: [line(), label, line()])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Design.Spacing.m
        row.arrangedSubviews[0].widthAnchor.constraint(equalTo: row.arrangedSubviews[2].widthAnchor).isActive = true
        // Purely visual: VoiceOver users meet the two buttons one after the other.
        row.isAccessibilityElement = false
        return row
    }

    private func configureErrorRow() {
        errorIcon.tintColor = Design.Color.error
        errorIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        errorIcon.setContentHuggingPriority(.required, for: .horizontal)
        errorIcon.isAccessibilityElement = false
        errorLabel.apply(.metadata)
        errorLabel.textColor = Design.Color.error
        errorRow.axis = .horizontal
        errorRow.alignment = .firstBaseline
        errorRow.spacing = Design.Spacing.s
        errorRow.isHidden = true
        errorRow.alpha = 0
    }

    private func layoutContent() {
        let seal = UILabel()
        seal.text = "単"
        seal.textAlignment = .center
        seal.textColor = Design.Color.onHero
        seal.backgroundColor = Design.Color.hero
        seal.font = Design.TextRole.mincho(size: 22, style: .title3, maximum: 30)
        seal.adjustsFontForContentSizeCategory = true
        seal.layer.cornerRadius = Design.Radius.chip
        seal.layer.cornerCurve = .continuous
        seal.clipsToBounds = true
        seal.isAccessibilityElement = false
        seal.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        seal.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true

        let wordmark = UILabel()
        wordmark.text = "Flashcard"
        wordmark.adjustsFontForContentSizeCategory = true
        wordmark.textColor = Design.Color.textPrimary
        let serif = UIFont.systemFont(ofSize: 20, weight: .semibold)
        wordmark.font = UIFontMetrics(forTextStyle: .title3).scaledFont(
            for: UIFont(descriptor: serif.fontDescriptor.withDesign(.serif) ?? serif.fontDescriptor, size: 20))

        let brand = UIStackView(arrangedSubviews: [seal, wordmark, UIView()])
        brand.axis = .horizontal
        brand.alignment = .center
        brand.spacing = Design.Spacing.m
        brand.isAccessibilityElement = true
        brand.accessibilityLabel = wordmark.text

        let heading = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        heading.axis = .vertical
        heading.spacing = Design.Spacing.s

        let fields = UIStackView(arrangedSubviews: [emailField, passwordField])
        fields.axis = .vertical
        fields.spacing = Design.Spacing.l + Design.Spacing.xs

        let actions = UIStackView(arrangedSubviews: [signInButton, orDivider, googleButton, appleButtons, continueWithoutLoginButton])
        actions.axis = .vertical
        actions.spacing = Design.Spacing.m

        // Spare height is shared between the gap under the brand and the foot of the screen (about 2:3), so the
        // form sits in the thumb zone without a large empty band between brand and headline.
        let spacer = UIView()
        let footer = UIView()
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.Spacing.xl).isActive = true
        let share = spacer.heightAnchor.constraint(equalTo: footer.heightAnchor, multiplier: 0.66)
        share.priority = .defaultHigh

        let stack = UIStackView(arrangedSubviews: [brand, spacer, heading, fields, errorRow, actions, footer])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.setCustomSpacing(Design.Spacing.xxl, after: heading)
        stack.setCustomSpacing(Design.Spacing.xl, after: fields)
        stack.setCustomSpacing(Design.Spacing.xl, after: errorRow)
        stack.setCustomSpacing(0, after: actions)
        stack.translatesAutoresizingMaskIntoConstraints = false
        share.isActive = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let margin = Design.Spacing.xl
        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        let preferredWidth = stack.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -2 * margin)
        // Stronger than any field's intrinsic width: a long password must scroll inside its field, not widen the form.
        preferredWidth.priority = UILayoutPriority(rawValue: 999)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: margin),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -margin),
            stack.centerXAnchor.constraint(equalTo: frame.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            preferredWidth,
            // Fill the visible height when the content is short; scroll when the keyboard or text size needs more.
            stack.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor, constant: -2 * margin),
            // The scroll content is exactly the column's width: no horizontal scrolling.
            content.widthAnchor.constraint(equalTo: frame.widthAnchor)
        ])
    }

    func subscribe() {
        presenter.viewState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in self?.render(state) })
            .disposed(by: disposeBag)
    }

    // MARK: - Rendering

    private func render(_ state: MailLoginViewState) {
        let isEmailLoading = state == .loading
        let isGoogleLoading = state == .signingInWithGoogle
        let isAppleLoading = state == .signingInWithApple
        let isBusy = isEmailLoading || isGoogleLoading || isAppleLoading
        var configuration = signInButton.configuration
        configuration?.showsActivityIndicator = isEmailLoading
        configuration?.title = isEmailLoading ? NSLocalizedString("Signing in…", comment: "") : presenter.loginButtonText
        signInButton.configuration = configuration
        var googleConfiguration = googleButton.configuration
        googleConfiguration?.showsActivityIndicator = isGoogleLoading
        googleConfiguration?.title = isGoogleLoading ? NSLocalizedString("Signing in…", comment: "") : presenter.googleButtonText
        googleButton.configuration = googleConfiguration
        signInButton.isEnabled = !isBusy
        googleButton.isEnabled = !isBusy
        appleButton.isEnabled = !isBusy
        appleButtonDark.isEnabled = !isBusy
        emailField.isEnabled = !isBusy
        passwordField.isEnabled = !isBusy
        passwordToggle.isEnabled = !isBusy

        if case .error(let message) = state {
            setError(message)
            UIAccessibility.post(notification: .announcement, argument: message)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } else {
            setError(nil)
        }
    }

    private func setError(_ message: String?) {
        let isVisible = message != nil
        if let message { errorLabel.text = message }
        guard errorRow.isHidden == isVisible else { return }
        let changes = {
            self.errorRow.isHidden = !isVisible
            self.errorRow.alpha = isVisible ? 1 : 0
        }
        if UIAccessibility.isReduceMotionEnabled || view.window == nil {
            changes()
        } else {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
                changes()
                self.view.layoutIfNeeded()
            })
        }
    }

    private func setPasswordRevealed(_ revealed: Bool) {
        let field = passwordField.textField
        if field.isSecureTextEntry == revealed {
            // Flipping secure entry on a live field discards its text and caret; put both back.
            let text = field.text
            let selection = field.selectedTextRange
            field.isSecureTextEntry = !revealed
            field.text = nil
            field.text = text
            field.selectedTextRange = selection
        }
        passwordToggle.configuration?.image = UIImage(systemName: revealed ? "eye.slash" : "eye")
        passwordToggle.accessibilityLabel = revealed
            ? NSLocalizedString("Hide password", comment: "")
            : NSLocalizedString("Show password", comment: "")
    }

    // MARK: - Actions

    @objc private func inputChanged() {
        // The message belongs to the previous attempt; once the user edits, stop showing it.
        if !errorRow.isHidden { setError(nil) }
    }

    @objc private func togglePasswordVisibility() {
        setPasswordRevealed(passwordField.textField.isSecureTextEntry)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func loginWithEmailAction() {
        view.endEditing(true)
        presenter.loginWithEmail(email: emailField.textField.text ?? "", password: passwordField.textField.text ?? "")
    }

    @objc private func loginWithGoogleAction() {
        view.endEditing(true)
        presenter.loginWithGoogle()
    }

    @objc private func loginWithAppleAction() {
        view.endEditing(true)
        presenter.loginWithApple()
    }

    @objc private func continueWithoutLoginAction() {
        view.endEditing(true)
        presenter.continueWithoutLogin()
    }
}

extension MailLoginViewController: UITextFieldDelegate, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl) && !(touch.view?.isDescendant(of: emailField) ?? false)
            && !(touch.view?.isDescendant(of: passwordField) ?? false)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField.textField {
            passwordField.textField.becomeFirstResponder()
        } else {
            loginWithEmailAction()
        }
        return false
    }
}

/// A persistent label above a rounded field. The border thickens and takes the accent while the field has focus,
/// so the active input is clear without relying on the caret alone.
private final class LoginFieldView: UIView {
    let textField = UITextField()
    private let titleLabel = UILabel()
    private let container = UIView()
    private let textTrailing: NSLayoutConstraint

    var isEnabled: Bool {
        get { textField.isEnabled }
        set {
            textField.isEnabled = newValue
            container.alpha = newValue ? 1 : 0.6
        }
    }

    init(title: String) {
        textTrailing = textField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Design.Spacing.l)
        super.init(frame: .zero)

        titleLabel.apply(.metadata)
        titleLabel.font = Design.TextRole.weighted(.footnote, weight: .semibold)
        titleLabel.text = title
        titleLabel.isAccessibilityElement = false

        container.backgroundColor = Design.Color.surface
        container.layer.cornerRadius = Design.Radius.control
        container.layer.cornerCurve = .continuous

        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.textColor = Design.Color.textPrimary
        textField.clearButtonMode = .never
        textField.accessibilityLabel = title
        textField.addTarget(self, action: #selector(focusChanged), for: [.editingDidBegin, .editingDidEnd])

        let stack = UIStackView(arrangedSubviews: [titleLabel, container])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Design.Spacing.l),
            textTrailing,
            textField.topAnchor.constraint(equalTo: container.topAnchor, constant: Design.Spacing.m),
            textField.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Design.Spacing.m)
        ])

        applyBorder(focused: false)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: LoginFieldView, _) in
            view.applyBorder(focused: view.textField.isFirstResponder)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LoginFieldView is built in code")
    }

    /// Trailing control (the password reveal button). The text stops where the control begins.
    func setAccessory(_ accessory: UIView) {
        accessory.translatesAutoresizingMaskIntoConstraints = false
        // The control keeps its own width; the text field takes whatever is left.
        accessory.setContentHuggingPriority(.required, for: .horizontal)
        accessory.setContentCompressionResistancePriority(.required, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        container.addSubview(accessory)
        textTrailing.isActive = false
        NSLayoutConstraint.activate([
            accessory.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            accessory.topAnchor.constraint(equalTo: container.topAnchor),
            accessory.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            accessory.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            textField.trailingAnchor.constraint(equalTo: accessory.leadingAnchor)
        ])
    }

    @objc private func focusChanged() {
        let focused = textField.isFirstResponder
        if UIAccessibility.isReduceMotionEnabled {
            applyBorder(focused: focused)
        } else {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.applyBorder(focused: focused)
            }
        }
    }

    private func applyBorder(focused: Bool) {
        let color = focused ? Design.Color.accent : Design.Color.border
        container.layer.borderColor = color.resolvedColor(with: traitCollection).cgColor
        container.layer.borderWidth = focused ? 2 : 1
    }
}
