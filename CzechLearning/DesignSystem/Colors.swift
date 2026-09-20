//
//  Colors.swift
//  CzechVocab / DesignSystem
//
//  Семантическая палитра. Значения сняты с макетов холста один в один.
//  Каждый токен динамический: цвет выбирается по userInterfaceStyle, поэтому
//  тёмная тема работает без ветвлений во вьюхах.
//
//  Правило: во вьюхах не должно быть ни одного литерала цвета.
//

import SwiftUI
import UIKit

// MARK: - Палитра

enum AppColor {

    // MARK: Фон и поверхности

    /// Фон всех экранов.
    static let background = dynamic(light: 0xF2F2F7, dark: 0x000000)
    /// Карточки и группы списка.
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    /// Вложенный блок внутри карточки — например, пример предложения.
    static let surfaceSecondary = dynamic(light: 0xF7F7FA, dark: 0x2C2C2E)
    /// Вторичные кнопки, трек сегментированного контрола, поле поиска.
    static let fill = dynamic(light: 0xE4E4E9, dark: 0x2C2C2E)
    /// Плейсхолдер картинки, подложка мелких иконок.
    static let fillSecondary = dynamic(light: 0xEDEDF2, dark: 0x2C2C2E)
    /// Подложка таб-бара.
    static let tabBar = dynamic(light: 0xF9F9F9, dark: 0x1C1C1E)

    // MARK: Разделители и треки

    static let separator = dynamic(light: 0xE5E5EA, dark: 0x38383A)
    static let separatorStrong = dynamic(light: 0xD8D8DC, dark: 0x38383A)
    /// Незаполненная часть прогресс-бара сессии.
    static let track = dynamic(light: 0xE0E0E5, dark: 0x38383A)

    // MARK: Текст

    static let label = dynamic(light: 0x1C1C1E, dark: 0xFFFFFF)
    static let labelSecondary = dynamic(light: 0x6E6E73, dark: 0xA1A1A6)
    static let labelTertiary = dynamic(light: 0x8A8A8E, dark: 0x8E8E93)
    /// Только для плейсхолдеров: контраст ниже 4,5:1, смысла не несёт.
    static let labelQuaternary = dynamic(light: 0xAEAEB2, dark: 0x6E6E73)
    static let chevron = dynamic(light: 0xC7C7CC, dark: 0x58585C)
    /// Текст поверх акцентной заливки.
    static let onAccent = Color.white

    // MARK: Акцент

    static let accent = dynamic(light: 0x007AFF, dark: 0x0A84FF)
    static let accentPressed = dynamic(light: 0x0062CC, dark: 0x409CFF)
    /// Фон круглой кнопки озвучки.
    static let accentTint = dynamic(light: 0xF1F7FF, dark: 0x0A2647)

    // MARK: Статусы

    static let success = dynamic(light: 0x34C759, dark: 0x30D158)
    static let successTint = dynamic(light: 0xE8F8EC, dark: 0x10301A)
    static let warning = dynamic(light: 0xFF9500, dark: 0xFF9F0A)
    static let warningTint = dynamic(light: 0xFFF3E3, dark: 0x3A2A0C)
    static let danger = dynamic(light: 0xFF3B30, dark: 0xFF453A)
    static let dangerTint = dynamic(light: 0xFFF0EE, dark: 0x3A1714)
    static let indigo = dynamic(light: 0x5856D6, dark: 0x5E5CE6)
    static let indigoTint = dynamic(light: 0xEFF1FF, dark: 0x1E1E42)
    static let purple = dynamic(light: 0xAF52DE, dark: 0xBF5AF2)

    // MARK: Callout примечания (ложные друзья)

    static let noteBackground = dynamic(light: 0xFFF6E5, dark: 0x3A2A0C)
    static let noteBorder = dynamic(light: 0xF4DFB4, dark: 0x5C4416)
    static let noteLabel = dynamic(light: 0x7A4E00, dark: 0xF0C46A)

    // MARK: Служебное

    fileprivate static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgb: dark)
                : UIColor(rgb: light)
        })
    }
}

// MARK: - Цвета оценок SM-2

extension AppColor {

    /// Набор цветов одной кнопки оценки.
    struct GradePalette {
        /// Заливка кнопки.
        let background: Color
        /// Подпись оценки.
        let label: Color
        /// Строка интервала над подписью.
        let interval: Color
    }

    /// Порядок на экране всегда `again → hard → good → easy`.
    static func grade(_ grade: ReviewGrade) -> GradePalette {
        switch grade {
        case .again:
            GradePalette(
                background: dynamic(light: 0xFFECEB, dark: 0x3A1714),
                label: dynamic(light: 0xD8372B, dark: 0xFF6961),
                interval: dynamic(light: 0xC7362C, dark: 0xFF6961)
            )
        case .hard:
            GradePalette(
                background: dynamic(light: 0xFFF3E3, dark: 0x3A2A0C),
                label: dynamic(light: 0xA66A00, dark: 0xFFB340),
                interval: dynamic(light: 0x9A6100, dark: 0xFFB340)
            )
        case .good:
            GradePalette(
                background: dynamic(light: 0xE6F6EA, dark: 0x12341C),
                label: dynamic(light: 0x1D8139, dark: 0x4CD964),
                interval: dynamic(light: 0x1C7A36, dark: 0x4CD964)
            )
        case .easy:
            GradePalette(
                background: dynamic(light: 0xE8F0FE, dark: 0x12294A),
                label: dynamic(light: 0x0062CC, dark: 0x409CFF),
                interval: dynamic(light: 0x0057B8, dark: 0x5AA9FF)
            )
        }
    }
}

// MARK: - График активности

extension AppColor {

    enum Chart {
        static let barLow = dynamic(light: 0xB8D8FF, dark: 0x1D4A82)
        static let barMid = dynamic(light: 0x8FC1FF, dark: 0x2C6FC4)
        static let barHigh = dynamic(light: 0x007AFF, dark: 0x0A84FF)
        static let barEmpty = dynamic(light: 0xE5E5EA, dark: 0x38383A)

        /// Цвет столбца по доле от максимума за период (0…1).
        static func bar(share: Double) -> Color {
            switch share {
            case ..<0.001: barEmpty
            case ..<0.55: barLow
            case ..<0.80: barMid
            default: barHigh
            }
        }
    }
}

// MARK: - Прогресс освоения

extension AppColor {

    /// Цвет полосы прогресса колоды или категории по доле выученного (0…1).
    /// Ниже 10% колода считается не начатой и красится нейтрально.
    static func progress(share: Double) -> Color {
        switch share {
        case ..<0.10: labelQuaternary
        case ..<0.40: warning
        default: success
        }
    }
}

// MARK: - Разбор hex

private extension UIColor {

    /// Инициализация из литерала вида `0xRRGGBB`. Без опциональных значений —
    /// разбирать строки в рантайме незачем, значения заданы константами.
    convenience init(rgb: UInt32) {
        let red = CGFloat((rgb >> 16) & 0xFF) / 255
        let green = CGFloat((rgb >> 8) & 0xFF) / 255
        let blue = CGFloat(rgb & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
