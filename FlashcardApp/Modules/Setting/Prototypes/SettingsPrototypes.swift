//
//  SettingsPrototypes.swift
//  FlashcardApp
//
//  Three distinct Settings screen directions for visual comparison.
//  Direction A: Native iOS Settings-app style
//  Direction B: Modern consumer-learning with warm branding
//  Direction C: Compact premium educational hierarchy
//

import SwiftUI

// MARK: - Shared Preview Models

struct PreviewUser {
    let name: String
    let email: String
    let avatarURL: String?
}

extension PreviewUser {
    static let signedIn = PreviewUser(
        name: "Thanh Nguyen",
        email: "thanh@example.com",
        avatarURL: nil
    )
}

enum PreviewAppearance: String, CaseIterable {
    case system, light, dark
    var label: String { rawValue.capitalized }
}

struct PreviewSettingsState {
    let user: PreviewUser?
    let appearance: PreviewAppearance
    let notificationsEnabled: Bool
    let notificationAuthorized: Bool
    let soundEnabled: Bool
    let language: String
    let appVersion: String
}

extension PreviewSettingsState {
    static let signedIn = PreviewSettingsState(
        user: .signedIn,
        appearance: .system,
        notificationsEnabled: true,
        notificationAuthorized: true,
        soundEnabled: true,
        language: "English",
        appVersion: "2.4.1"
    )

    static let signedOut = PreviewSettingsState(
        user: nil,
        appearance: .system,
        notificationsEnabled: false,
        notificationAuthorized: false,
        soundEnabled: true,
        language: "English",
        appVersion: "2.4.1"
    )
}

// MARK: - Direction A: Native iOS Settings Style

struct SettingsDirectionA: View {
    let state: PreviewSettingsState

    var body: some View {
        List {
            accountSectionA
            preferencesSectionA
            generalSectionA
            aboutSectionA
            if state.user != nil {
                logoutSectionA
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Settings", comment: ""))
        .navigationBarTitleDisplayMode(.large)
    }

    private var accountSectionA: some View {
        Section {
            Button(action: {}) {
                HStack(spacing: 14) {
                    accountAvatarA(size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.user?.name ?? NSLocalizedString("Sign In", comment: ""))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let email = state.user?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(NSLocalizedString("Tap to sign in or create an account", comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func accountAvatarA(size: CGFloat) -> some View {
        Group {
            if let _ = state.user?.avatarURL {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(state.user?.name.prefix(1) ?? "U"))
                            .font(.title3.bold())
                            .foregroundStyle(.blue)
                    )
            } else {
                Image(systemName: state.user != nil ? "person.circle.fill" : "person.circle")
                    .resizable()
                    .frame(width: size, height: size)
                    .foregroundStyle(state.user != nil ? Color.blue : Color.secondary)
            }
        }
    }

    private var preferencesSectionA: some View {
        Section(NSLocalizedString("Preferences", comment: "")) {
            NavigationLink(destination: EmptyView()) {
                HStack {
                    settingsLabelA(NSLocalizedString("Appearance", comment: ""), systemImage: "paintbrush.fill")
                    Spacer()
                    Text(state.appearance.label)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: Binding.constant(state.notificationsEnabled)) {
                settingsLabelA(NSLocalizedString("Notifications", comment: ""), systemImage: "bell.fill")
            }
            .disabled(!state.notificationAuthorized)

            if !state.notificationAuthorized {
                Button(NSLocalizedString("Open System Settings", comment: "")) {}
                    .foregroundStyle(.blue)
            }

            Toggle(isOn: Binding.constant(state.soundEnabled)) {
                settingsLabelA(NSLocalizedString("Sounds & Haptics", comment: ""), systemImage: "speaker.wave.2.fill")
            }
        }
    }

    private var generalSectionA: some View {
        Section(NSLocalizedString("General", comment: "")) {
            NavigationLink(destination: EmptyView()) {
                HStack {
                    settingsLabelA(NSLocalizedString("Language", comment: ""), systemImage: "globe")
                    Spacer()
                    Text(state.language)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink(destination: EmptyView()) {
                HStack {
                    settingsLabelA(NSLocalizedString("Privacy Policy", comment: ""), systemImage: "hand.raised.fill")
                    Spacer()
                }
            }
        }
    }

    private var aboutSectionA: some View {
        Section(NSLocalizedString("About", comment: "")) {
            NavigationLink(destination: EmptyView()) {
                HStack {
                    settingsLabelA(NSLocalizedString("About Flashcard", comment: ""), systemImage: "info.circle.fill")
                    Spacer()
                    Text(state.appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var logoutSectionA: some View {
        Section {
            Button(role: .destructive, action: {}) {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("Log Out", comment: ""))
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        }
    }
}

private func settingsLabelA(_ title: String, systemImage: String) -> some View {
    HStack(spacing: 12) {
        Image(systemName: systemImage)
            .frame(width: 28, height: 28)
            .foregroundStyle(.white)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor))
            .font(.subheadline)
        Text(title)
            .foregroundStyle(.primary)
    }
}

// MARK: - Direction B: Modern Consumer Learning

struct SettingsDirectionB: View {
    let state: PreviewSettingsState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                accountCardB
                sectionCardB(title: NSLocalizedString("Preferences", comment: ""), icon: "slider.horizontal.3") {
                    preferenceRowsB
                }
                sectionCardB(title: NSLocalizedString("General", comment: ""), icon: "gearshape") {
                    generalRowsB
                }
                sectionCardB(title: NSLocalizedString("About", comment: ""), icon: "info.circle") {
                    aboutRowsB
                }
                if state.user != nil {
                    logoutButtonB
                }
                versionFooterB
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(NSLocalizedString("Settings", comment: ""))
        .navigationBarTitleDisplayMode(.large)
    }

    private var accountCardB: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                accountAvatarB(size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.user?.name ?? NSLocalizedString("Welcome", comment: ""))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(state.user?.email ?? NSLocalizedString("Sign in to sync your progress", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.teal)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func accountAvatarB(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.teal.opacity(0.2), Color.teal.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            Text(String(state.user?.name.prefix(1) ?? "📚"))
                .font(.title2.bold())
                .foregroundStyle(.teal)
        }
    }

    private func sectionCardB<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
                Text(title.uppercased())
                    .font(.caption.bold())
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            content()
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
        )
    }

    private var preferenceRowsB: some View {
        VStack(spacing: 0) {
            rowB(icon: "paintbrush.fill", color: .orange, title: NSLocalizedString("Appearance", comment: ""), trailing: .text(state.appearance.label))
            Divider().padding(.leading, 52)
            rowB(icon: "bell.fill", color: .red, title: NSLocalizedString("Notifications", comment: ""), trailing: .toggle(state.notificationsEnabled, enabled: state.notificationAuthorized))
            Divider().padding(.leading, 52)
            rowB(icon: "speaker.wave.2.fill", color: .pink, title: NSLocalizedString("Sounds & Haptics", comment: ""), trailing: .toggle(state.soundEnabled, enabled: true))
        }
    }

    private var generalRowsB: some View {
        VStack(spacing: 0) {
            rowB(icon: "globe", color: .blue, title: NSLocalizedString("Language", comment: ""), trailing: .text(state.language))
            Divider().padding(.leading, 52)
            rowB(icon: "hand.raised.fill", color: .green, title: NSLocalizedString("Privacy Policy", comment: ""), trailing: .chevron)
        }
    }

    private var aboutRowsB: some View {
        VStack(spacing: 0) {
            rowB(icon: "info.circle.fill", color: .gray, title: NSLocalizedString("About Flashcard", comment: ""), trailing: .text(state.appVersion))
        }
    }

    private enum RowTrailing {
        case text(String)
        case toggle(Bool, enabled: Bool)
        case chevron
    }

    private func rowB(icon: String, color: Color, title: String, trailing: RowTrailing) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                )

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            switch trailing {
            case .text(let value):
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            case .toggle(let isOn, let enabled):
                Toggle("", isOn: Binding.constant(isOn))
                    .labelsHidden()
                    .disabled(!enabled)
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var logoutButtonB: some View {
        Button(role: .destructive, action: {}) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text(NSLocalizedString("Log Out", comment: ""))
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.red.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var versionFooterB: some View {
        Text("Flashcard v\(state.appVersion)")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}

// MARK: - Direction C: Compact Premium Educational

struct SettingsDirectionC: View {
    let state: PreviewSettingsState

    var body: some View {
        List {
            accountHeaderC
            learningStatusC
            preferencesSectionC
            supportSectionC
            if state.user != nil {
                logoutSectionC
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Settings", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accountHeaderC: some View {
        Section {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    accountAvatarC(size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.user?.name ?? NSLocalizedString("Guest Learner", comment: ""))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(state.user?.email ?? NSLocalizedString("Sign in for full features", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(action: {}) {
                        Text(state.user != nil ? NSLocalizedString("Edit", comment: "") : NSLocalizedString("Sign In", comment: ""))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.indigo.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func accountAvatarC(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.indigo.opacity(0.12))
                .frame(width: size, height: size)
            Text(String(state.user?.name.prefix(1) ?? "G"))
                .font(.title3.bold())
                .foregroundStyle(.indigo)
        }
    }

    private var learningStatusC: some View {
        Section {
            HStack(spacing: 0) {
                statusPillC(
                    icon: "flame.fill",
                    color: .orange,
                    label: "12",
                    sublabel: NSLocalizedString("day streak", comment: "")
                )
                Divider()
                    .frame(height: 36)
                statusPillC(
                    icon: "book.closed.fill",
                    color: .indigo,
                    label: "847",
                    sublabel: NSLocalizedString("cards reviewed", comment: "")
                )
                Divider()
                    .frame(height: 36)
                statusPillC(
                    icon: "trophy.fill",
                    color: .yellow,
                    label: "Lv.5",
                    sublabel: NSLocalizedString("learner level", comment: "")
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        } footer: {
            Text(NSLocalizedString("Your learning activity this month", comment: ""))
        }
    }

    private func statusPillC(icon: String, color: Color, label: String, sublabel: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
            Text(sublabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var preferencesSectionC: some View {
        Section(NSLocalizedString("Study Preferences", comment: "")) {
            compactRowC(icon: "paintbrush.fill", tint: .indigo, title: NSLocalizedString("Appearance", comment: ""), value: state.appearance.label)
            compactToggleC(icon: "bell.fill", tint: .indigo, title: NSLocalizedString("Study Reminders", comment: ""), isOn: state.notificationsEnabled, enabled: state.notificationAuthorized)
            compactToggleC(icon: "speaker.wave.2.fill", tint: .indigo, title: NSLocalizedString("Audio Feedback", comment: ""), isOn: state.soundEnabled, enabled: true)
            compactRowC(icon: "globe", tint: .indigo, title: NSLocalizedString("Language", comment: ""), value: state.language)
        }
    }

    private var supportSectionC: some View {
        Section(NSLocalizedString("Support & Legal", comment: "")) {
            compactRowC(icon: "hand.raised.fill", tint: .secondary, title: NSLocalizedString("Privacy Policy", comment: ""), value: nil)
            compactRowC(icon: "info.circle.fill", tint: .secondary, title: NSLocalizedString("About", comment: ""), value: "v\(state.appVersion)")
        }
    }

    private func compactRowC(icon: String, tint: Color, title: String, value: String?) -> some View {
        Button(action: {}) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if let value {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.quaternary)
            }
        }
        .buttonStyle(.plain)
    }

    private func compactToggleC(icon: String, tint: Color, title: String, isOn: Bool, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: Binding.constant(isOn))
                .labelsHidden()
                .disabled(!enabled)
        }
    }

    private var logoutSectionC: some View {
        Section {
            Button(role: .destructive, action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline)
                    Text(NSLocalizedString("Sign Out", comment: ""))
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Previews

#Preview("A · Native (Signed In)") {
    NavigationStack {
        SettingsDirectionA(state: .signedIn)
    }
}

#Preview("A · Native (Signed Out)") {
    NavigationStack {
        SettingsDirectionA(state: .signedOut)
    }
}

#Preview("B · Modern Learning (Signed In)") {
    NavigationStack {
        SettingsDirectionB(state: .signedIn)
    }
}

#Preview("B · Modern Learning (Signed Out)") {
    NavigationStack {
        SettingsDirectionB(state: .signedOut)
    }
}

#Preview("C · Compact Premium (Signed In)") {
    NavigationStack {
        SettingsDirectionC(state: .signedIn)
    }
}

#Preview("C · Compact Premium (Signed Out)") {
    NavigationStack {
        SettingsDirectionC(state: .signedOut)
    }
}

#Preview("A · Native Dark") {
    NavigationStack {
        SettingsDirectionA(state: .signedIn)
    }
    .preferredColorScheme(.dark)
}

#Preview("B · Modern Dark") {
    NavigationStack {
        SettingsDirectionB(state: .signedIn)
    }
    .preferredColorScheme(.dark)
}

#Preview("C · Premium Dark") {
    NavigationStack {
        SettingsDirectionC(state: .signedIn)
    }
    .preferredColorScheme(.dark)
}

#Preview("A · Large Type") {
    NavigationStack {
        SettingsDirectionA(state: .signedIn)
    }
    .environment(\.sizeCategory, .accessibilityLarge)
}

#Preview("B · Large Type") {
    NavigationStack {
        SettingsDirectionB(state: .signedIn)
    }
    .environment(\.sizeCategory, .accessibilityLarge)
}

#Preview("C · Large Type") {
    NavigationStack {
        SettingsDirectionC(state: .signedIn)
    }
    .environment(\.sizeCategory, .accessibilityLarge)
}
