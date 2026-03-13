import SwiftUI
import UIKit

private func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
}

extension Color {
    // MARK: - Semantic Colors

    static let accent: Color = adaptiveColor(
        light: UIColor(red: 107/255, green: 191/255, blue: 89/255, alpha: 1),
        dark: UIColor(red: 126/255, green: 211/255, blue: 104/255, alpha: 1)
    )

    static let surface: Color = adaptiveColor(
        light: UIColor(red: 250/255, green: 250/255, blue: 247/255, alpha: 1),
        dark: UIColor(red: 26/255, green: 26/255, blue: 28/255, alpha: 1)
    )

    static let surfaceCard: Color = adaptiveColor(
        light: UIColor.white,
        dark: UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 1)
    )

    static let textPrimary: Color = adaptiveColor(
        light: UIColor(red: 45/255, green: 45/255, blue: 45/255, alpha: 1),
        dark: UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1)
    )

    static let textSecondary: Color = Color(red: 142/255, green: 142/255, blue: 147/255)

    static let warmAccent: Color = Color(red: 244/255, green: 162/255, blue: 97/255)

    static let danger: Color = Color.red

    // MARK: - Legacy aliases (SheepCalendar theme compatibility)

    static let noDiaryGreen: Color = Color.accent
    static let noDiaryBlack: Color = Color.textPrimary
}
