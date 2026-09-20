//
//  SRSState.swift
//  CzechVocab / Domain / SRS
//
//  Состояние карточки как value-тип. Планировщик работает только с ним:
//  так вся таблица переходов раздела 6.2 тестируется без SwiftData.
//

import Foundation

nonisolated struct SRSState: Sendable, Equatable {

    var state: CardState
    var easeFactor: Double
    /// Текущий интервал в днях. В `learning`/`relearning` не используется.
    var intervalDays: Double
    /// Индекс шага в `learningSteps` или `relearningSteps`.
    var learningStepIndex: Int
    var dueDate: Date
    var repetitions: Int
    var lapses: Int
    /// Интервал, отложенный при провале: к нему возвращается карточка,
    /// успешно прошедшая переучивание.
    var storedIntervalDays: Double

    init(
        state: CardState = .new,
        easeFactor: Double = SRSConstants.initialEase,
        intervalDays: Double = 0,
        learningStepIndex: Int = 0,
        dueDate: Date = .distantPast,
        repetitions: Int = 0,
        lapses: Int = 0,
        storedIntervalDays: Double = 0
    ) {
        self.state = state
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.learningStepIndex = learningStepIndex
        self.dueDate = dueDate
        self.repetitions = repetitions
        self.lapses = lapses
        self.storedIntervalDays = storedIntervalDays
    }
}

// MARK: - Мост к хранилищу

nonisolated extension SRSState {

    /// Снимок состояния из записи прогресса.
    init(progress: WordProgress) {
        self.init(
            state: progress.state,
            easeFactor: progress.easeFactor,
            intervalDays: progress.intervalDays,
            learningStepIndex: progress.learningStepIndex,
            dueDate: progress.dueDate,
            repetitions: progress.repetitions,
            lapses: progress.lapses,
            storedIntervalDays: progress.storedIntervalDays
        )
    }

    /// Переносит состояние обратно в запись. Счётчики ответов и `isSuspended`
    /// живут отдельно: планировщик про них ничего не знает.
    func apply(to progress: WordProgress) {
        progress.stateRaw = state.rawValue
        progress.easeFactor = easeFactor
        progress.intervalDays = intervalDays
        progress.learningStepIndex = learningStepIndex
        progress.dueDate = dueDate
        progress.repetitions = repetitions
        progress.lapses = lapses
        progress.storedIntervalDays = storedIntervalDays
    }
}
