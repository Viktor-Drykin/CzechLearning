//
//  SRSScheduler.swift
//  CzechVocab / Domain / SRS
//
//  Модифицированный SM-2 (ТЗ раздел 6). Чистая функция без зависимостей:
//  вход — состояние, оценка и «сейчас», выход — новое состояние.
//
//  Случайный разброс интервала инжектируется, иначе тест на границы
//  1…365 дней был бы недетерминированным.
//

import Foundation

nonisolated struct SRSScheduler {

    /// Источник разброса: получает диапазон множителя и возвращает значение из него.
    typealias FuzzSource = @Sendable (ClosedRange<Double>) -> Double

    /// Разброс по умолчанию — равномерный в пределах ±5 %.
    static let randomFuzz: FuzzSource = { range in Double.random(in: range) }

    /// Разброса нет: интервал остаётся ровным. Используется в тестах и в предпросмотре
    /// интервалов на кнопках оценки, где пользователю нужно стабильное число.
    static let noFuzz: FuzzSource = { _ in 1.0 }

    // MARK: - Планирование

    static func schedule(
        progress: SRSState,
        grade: ReviewGrade,
        now: Date,
        fuzz: FuzzSource = randomFuzz
    ) -> SRSState {
        switch progress.state {
        case .new: scheduleNew(progress, grade: grade, now: now, fuzz: fuzz)
        case .learning: scheduleLearning(progress, grade: grade, now: now, fuzz: fuzz)
        case .review: scheduleReview(progress, grade: grade, now: now, fuzz: fuzz)
        case .relearning: scheduleRelearning(progress, grade: grade, now: now, fuzz: fuzz)
        }
    }

    /// Интервал, который получит карточка при каждой из четырёх оценок.
    /// Нужен кнопкам оценки: подписи считает планировщик, а не вьюха.
    static func previews(for progress: SRSState, now: Date) -> [ReviewGrade: TimeInterval] {
        var result: [ReviewGrade: TimeInterval] = [:]
        for grade in ReviewGrade.allCases {
            let next = schedule(progress: progress, grade: grade, now: now, fuzz: noFuzz)
            result[grade] = next.dueDate.timeIntervalSince(now)
        }
        return result
    }

    // MARK: - new

    private static func scheduleNew(
        _ progress: SRSState,
        grade: ReviewGrade,
        now: Date,
        fuzz: FuzzSource
    ) -> SRSState {
        var next = progress

        switch grade {
        case .again, .hard:
            next.state = .learning
            next.learningStepIndex = 0
            next.dueDate = now.addingTimeInterval(step(at: 0, in: SRSConstants.learningSteps))
        case .good:
            next.state = .learning
            next.learningStepIndex = 1
            next.dueDate = now.addingTimeInterval(step(at: 1, in: SRSConstants.learningSteps))
        case .easy:
            return graduate(progress, to: SRSConstants.easyIntervalDays, now: now, fuzz: fuzz)
        }

        next.intervalDays = 0
        return next
    }

    // MARK: - learning

    private static func scheduleLearning(
        _ progress: SRSState,
        grade: ReviewGrade,
        now: Date,
        fuzz: FuzzSource
    ) -> SRSState {
        var next = progress
        let steps = SRSConstants.learningSteps

        switch grade {
        case .again:
            next.learningStepIndex = 0
            next.dueDate = now.addingTimeInterval(step(at: 0, in: steps))
        case .hard:
            // Шаг не меняется — карточка повторяется на текущем интервале.
            next.dueDate = now.addingTimeInterval(step(at: progress.learningStepIndex, in: steps))
        case .good:
            let advanced = progress.learningStepIndex + 1
            if advanced >= steps.count {
                // Выпуск: карточка уходит в повторение с базовым ease.
                var graduated = progress
                graduated.easeFactor = SRSConstants.initialEase
                return graduate(
                    graduated,
                    to: SRSConstants.graduatingIntervalDays,
                    now: now,
                    fuzz: fuzz
                )
            }
            next.learningStepIndex = advanced
            next.dueDate = now.addingTimeInterval(step(at: advanced, in: steps))
        case .easy:
            return graduate(progress, to: SRSConstants.easyIntervalDays, now: now, fuzz: fuzz)
        }

        next.state = .learning
        next.intervalDays = 0
        return next
    }

    // MARK: - review

    private static func scheduleReview(
        _ progress: SRSState,
        grade: ReviewGrade,
        now: Date,
        fuzz: FuzzSource
    ) -> SRSState {
        var next = progress

        // Ease правится до расчёта интервала и не опускается ниже минимума.
        next.easeFactor = max(
            SRSConstants.minimumEase,
            progress.easeFactor + SRSConstants.easeDelta(for: grade)
        )

        guard grade != .again else {
            // Провал: уход в переучивание, интервал откладывается пополам.
            next.state = .relearning
            next.learningStepIndex = 0
            next.lapses += 1
            next.repetitions = 0
            next.storedIntervalDays = max(
                SRSConstants.minimumReviewIntervalDays,
                progress.intervalDays * SRSConstants.lapseIntervalMultiplier
            )
            next.dueDate = now.addingTimeInterval(step(at: 0, in: SRSConstants.relearningSteps))
            return next
        }

        let raw: Double = switch grade {
        case .hard: progress.intervalDays * SRSConstants.hardIntervalMultiplier
        case .good: progress.intervalDays * next.easeFactor
        case .easy: progress.intervalDays * next.easeFactor * SRSConstants.easyBonusMultiplier
        case .again: progress.intervalDays
        }

        next.state = .review
        next.repetitions = progress.repetitions + 1
        next.intervalDays = clampedInterval(raw)
        next.dueDate = due(from: now, intervalDays: next.intervalDays, fuzz: fuzz)
        return next
    }

    // MARK: - relearning

    private static func scheduleRelearning(
        _ progress: SRSState,
        grade: ReviewGrade,
        now: Date,
        fuzz: FuzzSource
    ) -> SRSState {
        var next = progress
        let restored = max(SRSConstants.minimumReviewIntervalDays, progress.storedIntervalDays)

        switch grade {
        case .again:
            next.learningStepIndex = 0
            next.dueDate = now.addingTimeInterval(step(at: 0, in: SRSConstants.relearningSteps))
            return next
        case .hard, .good:
            return graduate(progress, to: restored, now: now, fuzz: fuzz)
        case .easy:
            return graduate(
                progress,
                to: restored * SRSConstants.easyBonusMultiplier,
                now: now,
                fuzz: fuzz
            )
        }
    }

    // MARK: - Служебное

    /// Перевод карточки в повторение с заданным интервалом.
    private static func graduate(
        _ progress: SRSState,
        to intervalDays: Double,
        now: Date,
        fuzz: FuzzSource
    ) -> SRSState {
        var next = progress
        next.state = .review
        next.learningStepIndex = 0
        next.repetitions = progress.repetitions + 1
        next.storedIntervalDays = 0
        next.intervalDays = clampedInterval(intervalDays)
        next.dueDate = due(from: now, intervalDays: next.intervalDays, fuzz: fuzz)
        return next
    }

    /// Интервал зажимается в 1…365 дней (ТЗ 6.2).
    private static func clampedInterval(_ days: Double) -> Double {
        min(
            SRSConstants.maximumIntervalDays,
            max(SRSConstants.minimumReviewIntervalDays, days)
        )
    }

    /// Срок с разбросом ±5 %. Разброс применяется к дате, а не к сохранённому
    /// интервалу: иначе он накапливался бы от повторения к повторению.
    private static func due(from now: Date, intervalDays: Double, fuzz: FuzzSource) -> Date {
        let spread = SRSConstants.intervalFuzzPercent
        let multiplier = fuzz((1 - spread)...(1 + spread))
        let seconds = intervalDays * multiplier * SRSConstants.secondsPerDay
        return now.addingTimeInterval(seconds)
    }

    /// Шаг обучения по индексу; индекс за границами берёт последний шаг.
    private static func step(at index: Int, in steps: [TimeInterval]) -> TimeInterval {
        guard let last = steps.last else { return 60 }
        guard index >= 0, index < steps.count else { return last }
        return steps[index]
    }
}
