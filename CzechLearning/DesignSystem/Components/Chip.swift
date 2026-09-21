//
//  Chip.swift
//  CzechVocab / DesignSystem / Components
//
//  Чип: радиус 9, паддинг 5 × 10, фон `fill`, текст 12 semibold `labelSecondary`.
//  Часть речи, род/вид, уровень, категория, родительный падеж.
//

import SwiftUI

struct Chip: View {

    private let content: Text
    private var tint: Color?

    init(_ title: String) {
        content = Text(verbatim: title)
    }

    init(czech title: String) {
        content = .czech(title)
    }

    init(text: Text) {
        content = text
    }

    /// Чип с цветной подписью — для уровня колоды и статуса изучения.
    func tinted(_ color: Color) -> Chip {
        var copy = self
        copy.tint = color
        return copy
    }

    var body: some View {
        content
            .appFont(AppFont.caption)
            .fontWeight(.semibold)
            .foregroundStyle(tint ?? AppColor.labelSecondary)
            .padding(.vertical, Metrics.verticalPadding)
            .padding(.horizontal, Metrics.horizontalPadding)
            .background(
                AppColor.fill,
                in: RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
            )
    }

    private enum Metrics {
        static let verticalPadding: CGFloat = 5
        static let horizontalPadding: CGFloat = 10
    }
}

// MARK: - Чипы слова

extension Chip {

    /// Ряд чипов слова: часть речи, род/вид, родительный падеж, уровень.
    @MainActor
    static func row(for word: Word, showLevel: Bool = true) -> some View {
        WordChipRow(word: word, showLevel: showLevel)
    }
}

struct WordChipRow: View {

    let word: Word
    var showLevel = true

    var body: some View {
        HStack(spacing: AppSpacing.tight) {
            Chip(word.partOfSpeech.shortName)

            if let tag = word.grammarTag {
                Chip(tag.displayName)
            }
            if let genitive = word.genitiveForm {
                Chip(text: Text("р. п. ") + Text.czech(genitive))
            }
            if showLevel {
                Chip(word.level.rawValue)
            }
        }
    }
}

// MARK: - Подписи перечислений

extension PartOfSpeech {

    var displayName: String {
        switch self {
        case .noun: String(localized: "существительное")
        case .verb: String(localized: "глагол")
        case .adjective: String(localized: "прилагательное")
        case .adverb: String(localized: "наречие")
        case .numeral: String(localized: "числительное")
        case .pronoun: String(localized: "местоимение")
        case .preposition: String(localized: "предлог")
        case .conjunction: String(localized: "союз")
        case .particle: String(localized: "частица")
        case .interjection: String(localized: "междометие")
        case .phrase: String(localized: "фраза")
        }
    }

    /// Короткая форма для чипа на карточке.
    var shortName: String {
        switch self {
        case .noun: String(localized: "сущ.")
        case .verb: String(localized: "глаг.")
        case .adjective: String(localized: "прил.")
        case .adverb: String(localized: "нареч.")
        case .numeral: String(localized: "числ.")
        case .pronoun: String(localized: "мест.")
        case .preposition: String(localized: "предл.")
        case .conjunction: String(localized: "союз")
        case .particle: String(localized: "част.")
        case .interjection: String(localized: "межд.")
        case .phrase: String(localized: "фраза")
        }
    }

    /// Плейсхолдер картинки: SF Symbol по части речи (ТЗ раздел 10).
    var placeholderSymbol: String {
        switch self {
        case .noun: "cube"
        case .verb: "figure.walk"
        case .adjective: "paintpalette"
        case .adverb: "speedometer"
        case .numeral: "number"
        case .pronoun: "person"
        case .preposition: "arrow.turn.down.right"
        case .conjunction: "link"
        case .particle: "sparkle"
        case .interjection: "exclamationmark.bubble"
        case .phrase: "text.bubble"
        }
    }
}

extension GrammarTag {

    var displayName: String {
        switch self {
        case .masculine: String(localized: "м. р.")
        case .feminine: String(localized: "ж. р.")
        case .neuter: String(localized: "ср. р.")
        case .plural: String(localized: "мн. ч.")
        case .imperfective: String(localized: "несов. вид")
        case .perfective: String(localized: "сов. вид")
        }
    }
}

extension ReviewGrade {

    /// Подпись кнопки оценки. Порядок на экране всегда `again → hard → good → easy`.
    var displayName: String {
        switch self {
        case .again: String(localized: "Снова")
        case .hard: String(localized: "Трудно")
        case .good: String(localized: "Хорошо")
        case .easy: String(localized: "Легко")
        }
    }
}

extension StudyMode {

    var displayName: String {
        switch self {
        case .flashcards: String(localized: "Карточки")
        case .multipleChoice: String(localized: "Выбор варианта")
        case .typing: String(localized: "Письменный ввод")
        case .listening: String(localized: "Аудирование")
        case .matching: String(localized: "Пары")
        }
    }

    var symbolName: String {
        switch self {
        case .flashcards: "rectangle.on.rectangle.angled"
        case .multipleChoice: "list.bullet"
        case .typing: "keyboard"
        case .listening: "ear"
        case .matching: "square.grid.2x2"
        }
    }
}

extension TranslationLanguage {

    var displayName: String {
        switch self {
        case .russian: String(localized: "Русский")
        case .ukrainian: String(localized: "Українська")
        }
    }

    /// Язык перевода для VoiceOver: чешский текст помечается отдельно.
    var localeIdentifier: String {
        switch self {
        case .russian: "ru-RU"
        case .ukrainian: "uk-UA"
        }
    }
}
