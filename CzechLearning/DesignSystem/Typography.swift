//
//  Typography.swift
//  CzechVocab / DesignSystem
//
//  Шкала шрифтов. Системный SF Pro, сторонних гарнитур нет.
//  Размеры масштабируются через @ScaledMetric относительно текстового стиля,
//  поэтому Dynamic Type работает и на кастомных размерах (46 pt у чешского слова
//  системный TextStyle не покрывает).
//
//  Ограничение «до XXL» из ТЗ ставится один раз на корневой вьюхе:
//      RootView().dynamicTypeSize(...AppTypography.maximumSize)
//

import SwiftUI

// MARK: - Токен

struct AppFontToken: Sendable {
    let size: CGFloat
    let weight: Font.Weight
    let tracking: CGFloat
    /// Текстовый стиль, по которому масштабируется размер.
    let relativeTo: Font.TextStyle
    /// Моноширинные цифры — там, где число меняется на месте.
    let monospacedDigits: Bool

    init(
        size: CGFloat,
        weight: Font.Weight = .regular,
        tracking: CGFloat = 0,
        relativeTo: Font.TextStyle,
        monospacedDigits: Bool = false
    ) {
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.relativeTo = relativeTo
        self.monospacedDigits = monospacedDigits
    }
}

// MARK: - Шкала

enum AppFont {

    // Заголовки экранов
    static let largeTitle = AppFontToken(size: 34, weight: .bold, tracking: -0.6, relativeTo: .largeTitle)

    // Слова и переводы
    /// Чешское слово на лицевой стороне карточки.
    static let wordDisplay = AppFontToken(size: 46, weight: .semibold, tracking: -1.2, relativeTo: .largeTitle)
    /// Слово в детальной карточке и вопрос в режиме выбора варианта.
    static let wordDisplayCompact = AppFontToken(size: 38, weight: .semibold, tracking: -1.0, relativeTo: .largeTitle)
    /// Перевод на обороте карточки.
    static let answerDisplay = AppFontToken(size: 32, weight: .semibold, tracking: -0.7, relativeTo: .title)
    /// Чешское слово на обороте, вопрос в письменном вводе.
    static let title1 = AppFontToken(size: 30, weight: .semibold, tracking: -0.8, relativeTo: .title)

    // Секции
    static let title2 = AppFontToken(size: 26, weight: .bold, tracking: -0.5, relativeTo: .title2)
    static let title3 = AppFontToken(size: 22, weight: .bold, tracking: -0.3, relativeTo: .title3)

    // Числа
    static let statNumber = AppFontToken(size: 34, weight: .semibold, tracking: -1.0, relativeTo: .title, monospacedDigits: true)
    static let statNumberSmall = AppFontToken(size: 28, weight: .semibold, tracking: -0.8, relativeTo: .title2, monospacedDigits: true)

    // Текст
    static let headline = AppFontToken(size: 17, weight: .semibold, relativeTo: .headline)
    static let body = AppFontToken(size: 17, relativeTo: .body)
    static let callout = AppFontToken(size: 16, relativeTo: .callout)
    static let subheadline = AppFontToken(size: 15, relativeTo: .subheadline)
    static let footnote = AppFontToken(size: 13, relativeTo: .footnote)
    static let caption = AppFontToken(size: 12, relativeTo: .caption)

    // Служебное
    /// Интервал над кнопкой оценки.
    static let caption2 = AppFontToken(size: 11, weight: .semibold, relativeTo: .caption2, monospacedDigits: true)
    /// Заголовок группы списка. Применять вместе с `.textCase(.uppercase)`.
    static let sectionHeader = AppFontToken(size: 12, weight: .semibold, tracking: 0.4, relativeTo: .caption)
    /// Подпись вкладки таб-бара.
    static let tabLabel = AppFontToken(size: 10, weight: .medium, relativeTo: .caption2)
}

// MARK: - Общие правила

enum AppTypography {
    /// Верхняя граница Dynamic Type по ТЗ (раздел 12).
    static let maximumSize: DynamicTypeSize = .xxLarge
}

// MARK: - Применение

extension View {
    /// Единственный допустимый способ задать шрифт во вьюхах.
    func appFont(_ token: AppFontToken) -> some View {
        modifier(AppFontModifier(token))
    }
}

private struct AppFontModifier: ViewModifier {

    @ScaledMetric private var scaledSize: CGFloat
    private let token: AppFontToken

    init(_ token: AppFontToken) {
        self.token = token
        _scaledSize = ScaledMetric(wrappedValue: token.size, relativeTo: token.relativeTo)
    }

    func body(content: Content) -> some View {
        let styled = content
            .font(.system(size: scaledSize, weight: token.weight))
            .tracking(token.tracking)

        if token.monospacedDigits {
            styled.monospacedDigit()
        } else {
            styled
        }
    }
}

// MARK: - Чешский текст и VoiceOver

enum AppText {

    /// Чешская строка, помеченная языком `cs-CZ`.
    ///
    /// VoiceOver читает её чешским голосом, а окружающий интерфейс — языком системы.
    /// Применять ко всему чешскому: заголовку карточки, примерам, вариантам ответа
    /// в обратном направлении показа.
    static func czech(_ string: String) -> AttributedString {
        var attributed = AttributedString(string)
        attributed.languageIdentifier = "cs-CZ"
        return attributed
    }
}

extension Text {
    /// `Text.czech("okurka")` — короткая форма для `AppText.czech`.
    static func czech(_ string: String) -> Text {
        Text(AppText.czech(string))
    }
}
