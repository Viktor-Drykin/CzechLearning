//
//  WordProgress.swift
//  CzechVocab / Data / Models
//
//  Состояние SM-2 для одного слова. Создаётся лениво — при первом показе карточки,
//  а не при импорте: слов 1744, а в ротации у пользователя обычно сотни.
//

import Foundation
import SwiftData

@Model
final class WordProgress {

    var word: Word?
    var stateRaw: Int
    var easeFactor: Double
    var intervalDays: Double
    var learningStepIndex: Int
    var dueDate: Date
    var repetitions: Int
    var lapses: Int
    var totalReviews: Int
    var correctReviews: Int
    var lastReviewedAt: Date?
    /// Пользователь исключил слово из ротации.
    var isSuspended: Bool
    /// Интервал, сохранённый при провале в `relearning`, — к нему возвращаемся
    /// после успешного переучивания (ТЗ 6.2).
    var storedIntervalDays: Double

    init(
        word: Word? = nil,
        stateRaw: Int = CardState.new.rawValue,
        easeFactor: Double = SRSConstants.initialEase,
        intervalDays: Double = 0,
        learningStepIndex: Int = 0,
        dueDate: Date = .distantPast,
        repetitions: Int = 0,
        lapses: Int = 0,
        totalReviews: Int = 0,
        correctReviews: Int = 0,
        lastReviewedAt: Date? = nil,
        isSuspended: Bool = false,
        storedIntervalDays: Double = 0
    ) {
        self.word = word
        self.stateRaw = stateRaw
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.learningStepIndex = learningStepIndex
        self.dueDate = dueDate
        self.repetitions = repetitions
        self.lapses = lapses
        self.totalReviews = totalReviews
        self.correctReviews = correctReviews
        self.lastReviewedAt = lastReviewedAt
        self.isSuspended = isSuspended
        self.storedIntervalDays = storedIntervalDays
    }
}

nonisolated extension WordProgress {

    var state: CardState {
        CardState(rawValue: stateRaw) ?? .new
    }

    /// Слово считается выученным, если оно в повторении с интервалом от 21 дня (ТЗ 8.3).
    var isLearned: Bool {
        state == .review && intervalDays >= SRSConstants.learnedIntervalDays
    }

    /// Слово в изучении: начато, но ещё не выучено.
    var isInProgress: Bool {
        state != .new && !isLearned
    }

    /// Доля верных ответов. `nil`, пока ответов не было.
    var accuracy: Double? {
        guard totalReviews > 0 else { return nil }
        return Double(correctReviews) / Double(totalReviews)
    }

    /// Критерий «трудного» слова из фильтра колоды (ТЗ 6.5).
    var isDifficult: Bool {
        if lapses >= SRSConstants.difficultLapseThreshold { return true }
        guard totalReviews >= SRSConstants.difficultMinimumReviews,
              let accuracy
        else { return false }
        return accuracy < SRSConstants.difficultAccuracyThreshold
    }
}
