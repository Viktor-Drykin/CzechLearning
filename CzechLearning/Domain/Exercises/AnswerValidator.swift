//
//  AnswerValidator.swift
//  CzechVocab / Domain / Exercises
//
//  Проверка письменного ответа (ТЗ 7.3). Пять исходов, каждый со своим
//  потолком оценки.
//
//  Решение про диакритику осознанное: заставлять набирать `ř` и `ě` на
//  системной клавиатуре — барьер, но игнорировать её полностью нельзя,
//  поэтому ответ без диакритики засчитывается, но не выше `hard`.
//

import Foundation

nonisolated enum AnswerValidator {

    enum Outcome: Sendable, Equatable {
        /// Точное совпадение.
        case correct
        /// Верно, но без диакритики: показываем правильное написание.
        case correctWithoutDiacritics
        /// Опечатка в одну букву при длине слова от пяти символов.
        case almostCorrect
        /// Неверно.
        case incorrect
        /// Пользователь нажал «Не знаю».
        case gaveUp

        var isAccepted: Bool {
            switch self {
            case .correct, .correctWithoutDiacritics, .almostCorrect: true
            case .incorrect, .gaveUp: false
            }
        }

        /// Потолок оценки для этого исхода. `nil` — потолка нет,
        /// оценка считается по времени ответа.
        var gradeCeiling: ReviewGrade? {
            switch self {
            case .correct: nil
            case .correctWithoutDiacritics, .almostCorrect: .hard
            case .incorrect, .gaveUp: .again
            }
        }
    }

    /// Минимальная длина слова, при которой прощается опечатка.
    static let typoMinimumLength = 5
    /// Максимальное расстояние Левенштейна для «почти верно».
    static let typoMaximumDistance = 1

    // MARK: - Проверка

    static func validate(answer: String, expected: String) -> Outcome {
        let given = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let target = expected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !given.isEmpty else { return .incorrect }
        if given == target { return .correct }

        let foldedGiven = TextNormalization.foldDiacritics(given)
        let foldedTarget = TextNormalization.foldDiacritics(target)
        if foldedGiven == foldedTarget { return .correctWithoutDiacritics }

        // Опечатку прощаем только у слов подлиннее: в «ne» и «ano»
        // одна буква — это уже другое слово.
        if foldedTarget.count >= typoMinimumLength,
           TextNormalization.levenshteinDistance(foldedGiven, foldedTarget) <= typoMaximumDistance {
            return .almostCorrect
        }

        return .incorrect
    }

    /// Итоговая оценка: время ответа, ограниченное потолком исхода.
    static func grade(for outcome: Outcome, responseTime: TimeInterval) -> ReviewGrade {
        guard outcome.isAccepted else { return .again }

        let byTime = SRSConstants.grade(correct: true, responseTime: responseTime)
        guard let ceiling = outcome.gradeCeiling else { return byTime }
        return byTime.rawValue > ceiling.rawValue ? ceiling : byTime
    }

    // MARK: - Подсветка диакритики

    /// Части правильного написания с пометкой, какие символы пользователь
    /// пропустил: подсвечиваем именно диакритические знаки.
    struct Highlight: Sendable, Equatable {
        let character: Character
        let isDiacritic: Bool
    }

    static func highlightDiacritics(in expected: String) -> [Highlight] {
        expected.map { character in
            Highlight(
                character: character,
                isDiacritic: String(character) != TextNormalization.strippingDiacritics(String(character))
            )
        }
    }
}
