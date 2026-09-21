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
///
/// Мужской род всегда размечен одушевлённостью: в чешском она меняет склонение
/// (винительный одушевлённых совпадает с родительным — *vidím psa*,
/// у неодушевлённых с именительным — *vidím hrad*). Значение `м.р.` без
/// уточнения — ошибка данных, см. `GrammarTag.isIncompleteMasculine`.
nonisolated enum GrammarTag: String, Codable, CaseIterable, Sendable {
    case masculineAnimate
    case masculineInanimate
    case feminine
    case neuter
    case plural
    case imperfective
    case perfective

    var csvValue: String {
        switch self {
        case .masculineAnimate: "м.р. одуш."
        case .masculineInanimate: "м.р. неодуш."
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

    /// Мужской род без пометки одушевлённости. По ТЗ 3.3 в данных такого нет,
    /// и импорт считает это ошибкой валидации, а не молча теряет пометку.
    static func isIncompleteMasculine(csvValue: String) -> Bool {
        csvValue.trimmingCharacters(in: .whitespaces) == "м.р."
    }
}

// MARK: - Род существительного

/// Род для цветовой подсказки на карточке. Отдельно от `GrammarTag`, потому что
/// тот описывает ещё и вид глагола, а красим только существительные.
nonisolated enum NounGender: String, Codable, CaseIterable, Sendable {
    case feminine
    case neuter
    case masculineAnimate
    case masculineInanimate

    /// Род из грамматической пометки. `nil` для всего, у чего рода нет:
    /// вида глагола, слов только во множественном числе, пустой пометки.
    init?(grammarTag: GrammarTag?) {
        switch grammarTag {
        case .feminine: self = .feminine
        case .neuter: self = .neuter
        case .masculineAnimate: self = .masculineAnimate
        case .masculineInanimate: self = .masculineInanimate
        case .plural, .imperfective, .perfective, .none: return nil
        }
    }

    /// Разбор прямо из значения CSV. `м.р.` без уточнения одушевлённости
    /// показываем как неодушевлённый — правило «не знаешь, одушевлённый или
    /// нет, значит синий».
    init?(csvValue: String) {
        let trimmed = csvValue.trimmingCharacters(in: .whitespaces)
        if GrammarTag.isIncompleteMasculine(csvValue: trimmed) {
            self = .masculineInanimate
            return
        }
        guard let tag = GrammarTag(csvValue: trimmed),
              let gender = NounGender(grammarTag: tag)
        else { return nil }
        self = gender
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
