//
//  SRSConstants.swift
//  CzechVocab / Domain / SRS
//
//  Константы модифицированного SM-2 (ТЗ 6.1) и пороги, производные от них.
//  Отдельным файлом, потому что на них ссылаются и модели, и планировщик,
//  и построитель очереди.
//

import Foundation

nonisolated enum SRSConstants {

    // MARK: Ease

    static let initialEase = 2.5
    static let minimumEase = 1.3

    /// Поправка ease по оценке в состоянии `review`.
    static func easeDelta(for grade: ReviewGrade) -> Double {
        switch grade {
        case .again: -0.20
        case .hard: -0.15
        case .good: 0
        case .easy: +0.15
        }
    }

    // MARK: Шаги обучения

    static let learningSteps: [TimeInterval] = [60, 600]
    static let relearningSteps: [TimeInterval] = [600]

    // MARK: Интервалы

    static let graduatingIntervalDays = 1.0
    static let easyIntervalDays = 4.0
    static let lapseIntervalMultiplier = 0.5
    static let hardIntervalMultiplier = 1.2
    static let easyBonusMultiplier = 1.3
    static let minimumReviewIntervalDays = 1.0
    static let maximumIntervalDays = 365.0
    static let intervalFuzzPercent = 0.05

    static let secondsPerDay: TimeInterval = 86_400

    // MARK: Пороги

    /// Слово считается выученным начиная с этого интервала (ТЗ 8.3).
    static let learnedIntervalDays = 21.0

    /// «Трудное» слово: столько провалов достаточно само по себе.
    static let difficultLapseThreshold = 2
    /// …либо доля верных ниже порога при хотя бы стольких ответах.
    static let difficultMinimumReviews = 4
    static let difficultAccuracyThreshold = 0.60

    // MARK: Маппинг времени ответа в оценку (ТЗ 6.3)

    /// Верный ответ быстрее этого — `easy`.
    static let fastAnswerSeconds: TimeInterval = 3
    /// Верный ответ дольше этого — `hard`.
    static let slowAnswerSeconds: TimeInterval = 10

    /// Оценка для режимов без кнопок: выбор варианта, ввод, аудирование.
    static func grade(correct: Bool, responseTime: TimeInterval) -> ReviewGrade {
        guard correct else { return .again }
        if responseTime > slowAnswerSeconds { return .hard }
        if responseTime < fastAnswerSeconds { return .easy }
        return .good
    }

    // MARK: Лимиты по умолчанию

    static let defaultNewCardsPerDay = 10
    static let defaultReviewsPerDay = 200
    /// Значение «без лимита» в настройках.
    static let unlimited = Int.max
}
