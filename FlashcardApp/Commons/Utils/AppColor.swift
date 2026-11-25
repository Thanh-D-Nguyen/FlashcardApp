//
//  AppColor.swift
//  FlashcardApp
//
//  Legacy color namespace retained as a thin compatibility shim over `Design.Color`.
//  New code should reference `Design.Color` directly.
//

import UIKit

enum AppColors {
    static var primary: UIColor { Design.Color.accent }
    static var secondary: UIColor { Design.Color.hero }
    static var accentGreen: UIColor { Design.Color.success }
    static var accentRed: UIColor { Design.Color.error }
    static var background: UIColor { Design.Color.background }
    static var cardBackground: UIColor { Design.Color.surface }
    static var textPrimary: UIColor { Design.Color.textPrimary }
    static var textSecondary: UIColor { Design.Color.textSecondary }
    static var highlightYellow: UIColor { Design.Color.warning }
    static var lightGray: UIColor { Design.Color.surfaceTint }
    static var darkGray: UIColor { Design.Color.textSecondary }
    static var interactivePurple: UIColor { Design.Color.accent }
    static var notificationOrange: UIColor { Design.Color.warning }
    static var imageBackground: UIColor { Design.Color.surfaceTint }
    static var quizCorrect: UIColor { Design.Color.success }
    static var quizIncorrect: UIColor { Design.Color.error }
    static var dictionaryBackground: UIColor { Design.Color.background }
    static var placeholderText: UIColor { Design.Color.placeholder }
    static var separatorLine: UIColor { Design.Color.separator }
}
