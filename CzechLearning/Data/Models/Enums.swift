//
//  Enums.swift
//  CzechVocab / Data / Models
//
//  Перечисления предметной области. Все — value-типы без изоляции:
//  ими пользуется и UI на главном акторе, и импортёр на фоновом.
//

import Foundation

// MARK: - Часть речи

/// Ровно 11 значений из раздела 3.3 ТЗ.
nonisolated enum PartOfSpeech: String, Codable, CaseIterable, Sendable {
    case noun
    case verb
    case adjective
    case adverb
    case numeral
    case pronoun
    case preposition
    case conjunction
    case particle
    case interjection
    case phrase

    /// Сокращение в колонке `part_of_speech` CSV.
    var csvValue: String {
        switch self {
        case .noun: "сущ."
        case .verb: "гл."
        case .adjective: "прил."
        case .adverb: "нареч."
        case .numeral: "числ."
        case .pronoun: "мест."
        case .preposition: "предл."
        case .conjunction: "союз"
        case .particle: "частица"
        case .interjection: "межд."
        case .phrase: "фраза"
        }
    }

    /// Разбор русского сокращения из CSV. Неизвестное значение — невалидная строка.
    init?(csvValue: String) {
        let trimmed = csvValue.trimmingCharacters(in: .whitespaces)
        guard let match = Self.allCases.first(where: { $0.csvValue == trimmed }) else {
            return nil
        }
        self = match
    }
}

// MARK: - Род и вид

/// Род существительного или вид глагола — колонка `gender_aspect`.
/// Пустая строка в CSV означает отсутствие пометки, а не ошибку.
nonisolated enum GrammarTag: String, Codable, CaseIterable, Sendable {
    case masculine
    case feminine
    case neuter
    case plural
    case imperfective
    case perfective

    var csvValue: String {
        switch self {
        case .masculine: "м.р."
        case .feminine: "ж.р."
        case .neuter: "ср.р."
        case .plural: "мн.ч."
        case .imperfective: "несов."
        case .perfective: "сов."
        }
    }

    /// `nil` и для пустой строки, и для мусора: отличает их вызывающий код.
    init?(csvValue: String) {
        let trimmed = csvValue.trimmingCharacters(in: .whitespaces)
        guard let match = Self.allCases.first(where: { $0.csvValue == trimmed }) else {
            return nil
        }
        self = match
    }
}

// MARK: - Уровень

nonisolated enum CEFRLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"

    /// Порядок подачи: A1 → A2 → B1.
    private var order: Int {
        switch self {
        case .a1: 0
        case .a2: 1
        case .b1: 2
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.order < rhs.order
    }
}

// MARK: - Язык перевода

/// Язык подсказок на карточках. С языком интерфейса не связан (ТЗ раздел 11).
nonisolated enum TranslationLanguage: String, Codable, CaseIterable, Sendable {
    case russian
    case ukrainian
}

// MARK: - Состояние карточки

nonisolated enum CardState: Int, Codable, CaseIterable, Sendable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

// MARK: - Оценка

/// Порядок на всех экранах слева направо: `again → hard → good → easy`.
nonisolated enum ReviewGrade: Int, Codable, CaseIterable, Sendable {
    case again = 0
    case hard = 1
    case good = 2
    case easy = 3
}

// MARK: - Режим тренировки

nonisolated enum StudyMode: String, Codable, CaseIterable, Sendable {
    case flashcards
    case multipleChoice
    case typing
    case listening
    case matching
}

// MARK: - Направление показа

/// Настройка «Направление карточек» (ТЗ раздел 8.4).
nonisolated enum CardDirection: String, Codable, CaseIterable, Sendable {
    /// Чешское слово в вопросе, перевод в ответе.
    case czechToTranslation
    /// Перевод в вопросе, чешское слово в ответе.
    case translationToCzech
    /// Случайный выбор одного из двух на каждой карточке.
    case mixed

    /// Разворачивает `mixed` в конкретное направление для одной карточки.
    func resolved(random: () -> Bool = { Bool.random() }) -> CardDirection {
        switch self {
        case .mixed: random() ? .czechToTranslation : .translationToCzech
        default: self
        }
    }
}
