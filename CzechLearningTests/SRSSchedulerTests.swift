//
//  SRSSchedulerTests.swift
//  CzechLearningTests
//
//  Полный обход таблицы переходов раздела 6.2 ТЗ плюс граничные случаи.
//

import Foundation
import Testing

@testable import CzechLearning

@Suite("Планировщик SM-2")
struct SRSSchedulerTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let minute: TimeInterval = 60
    private let tenMinutes: TimeInterval = 600
    private let day = SRSConstants.secondsPerDay

    /// Без разброса — иначе сравнивать даты бессмысленно.
    private func schedule(_ state: SRSState, _ grade: ReviewGrade) -> SRSState {
        SRSScheduler.schedule(progress: state, grade: grade, now: now, fuzz: SRSScheduler.noFuzz)
    }

    private func seconds(_ state: SRSState) -> TimeInterval {
        state.dueDate.timeIntervalSince(now)
    }

    // MARK: - new

    @Test("new + again → learning, шаг 0, через минуту")
    func newAgain() {
        let next = schedule(SRSState(), .again)
        #expect(next.state == .learning)
        #expect(next.learningStepIndex == 0)
        #expect(seconds(next) == minute)
    }

    @Test("new + hard → learning, шаг 0, через минуту")
    func newHard() {
        let next = schedule(SRSState(), .hard)
        #expect(next.state == .learning)
        #expect(next.learningStepIndex == 0)
        #expect(seconds(next) == minute)
    }

    @Test("new + good → learning, шаг 1, через десять минут")
    func newGood() {
        let next = schedule(SRSState(), .good)
        #expect(next.state == .learning)
        #expect(next.learningStepIndex == 1)
        #expect(seconds(next) == tenMinutes)
    }

    @Test("new + easy → review с интервалом 4 дня")
    func newEasy() {
        let next = schedule(SRSState(), .easy)
        #expect(next.state == .review)
        #expect(next.intervalDays == SRSConstants.easyIntervalDays)
        #expect(seconds(next) == 4 * day)
    }

    // MARK: - learning

    @Test("learning + again сбрасывает шаг в 0")
    func learningAgain() {
        let state = SRSState(state: .learning, learningStepIndex: 1)
        let next = schedule(state, .again)
        #expect(next.state == .learning)
        #expect(next.learningStepIndex == 0)
        #expect(seconds(next) == minute)
    }

    @Test("learning + hard оставляет шаг на месте")
    func learningHard() {
        let state = SRSState(state: .learning, learningStepIndex: 1)
        let next = schedule(state, .hard)
        #expect(next.state == .learning)
        #expect(next.learningStepIndex == 1)
        #expect(seconds(next) == tenMinutes)
    }

    @Test("learning + good продвигает шаг внутри массива")
    func learningGoodAdvances() {
        let state = SRSState(state: .learning, learningStepIndex: 0)
        let next = schedule(state, .good)
        #expect(next.state == .learning)
        #expect(next.learningStepIndex == 1)
        #expect(seconds(next) == tenMinutes)
    }

    @Test("learning + good на последнем шаге выпускает карточку с интервалом 1 день и ease 2.5")
    func learningGoodGraduates() {
        let state = SRSState(state: .learning, easeFactor: 1.9, learningStepIndex: 1)
        let next = schedule(state, .good)
        #expect(next.state == .review)
        #expect(next.intervalDays == SRSConstants.graduatingIntervalDays)
        #expect(next.easeFactor == SRSConstants.initialEase)
        #expect(seconds(next) == day)
    }

    @Test("learning + easy выпускает карточку с интервалом 4 дня")
    func learningEasy() {
        let state = SRSState(state: .learning, learningStepIndex: 0)
        let next = schedule(state, .easy)
        #expect(next.state == .review)
        #expect(next.intervalDays == SRSConstants.easyIntervalDays)
    }

    // MARK: - review: ease

    @Test(
        "Ease правится по оценке",
        arguments: [
            (ReviewGrade.again, 2.30),
            (.hard, 2.35),
            (.good, 2.50),
            (.easy, 2.65),
        ]
    )
    func reviewEaseDelta(grade: ReviewGrade, expected: Double) {
        let state = SRSState(state: .review, easeFactor: 2.5, intervalDays: 10)
        let next = schedule(state, grade)
        #expect(abs(next.easeFactor - expected) < 0.0001)
    }

    @Test("Ease не опускается ниже 1.3, сколько бы ни было провалов")
    func easeFloor() {
        var state = SRSState(state: .review, easeFactor: 1.35, intervalDays: 10)
        for _ in 0..<10 {
            state = schedule(state, .again)
            state.state = .review
        }
        #expect(state.easeFactor == SRSConstants.minimumEase)
    }

    // MARK: - review: интервалы

    @Test("review + hard умножает интервал на 1.2")
    func reviewHardInterval() {
        let state = SRSState(state: .review, easeFactor: 2.5, intervalDays: 10)
        let next = schedule(state, .hard)
        #expect(abs(next.intervalDays - 12) < 0.0001)
        #expect(next.state == .review)
    }

    @Test("review + good умножает интервал на ease")
    func reviewGoodInterval() {
        let state = SRSState(state: .review, easeFactor: 2.5, intervalDays: 10)
        let next = schedule(state, .good)
        #expect(abs(next.intervalDays - 25) < 0.0001)
    }

    @Test("review + easy умножает интервал на ease и ещё на 1.3")
    func reviewEasyInterval() {
        let state = SRSState(state: .review, easeFactor: 2.5, intervalDays: 10)
        let next = schedule(state, .easy)
        // ease становится 2.65, затем 10 × 2.65 × 1.3
        #expect(abs(next.intervalDays - 34.45) < 0.0001)
    }

    @Test("review + again уводит в relearning, откладывает половину интервала и считает провал")
    func reviewAgain() {
        let state = SRSState(
            state: .review,
            easeFactor: 2.5,
            intervalDays: 30,
            repetitions: 4,
            lapses: 1
        )
        let next = schedule(state, .again)
        #expect(next.state == .relearning)
        #expect(next.learningStepIndex == 0)
        #expect(next.lapses == 2)
        #expect(next.repetitions == 0)
        #expect(next.storedIntervalDays == 15)
        #expect(seconds(next) == tenMinutes)
    }

    @Test("Отложенный интервал не опускается ниже одного дня")
    func storedIntervalFloor() {
        let state = SRSState(state: .review, intervalDays: 1)
        let next = schedule(state, .again)
        #expect(next.storedIntervalDays == SRSConstants.minimumReviewIntervalDays)
    }

    @Test("Интервал не превышает 365 дней")
    func intervalCeiling() {
        let state = SRSState(state: .review, easeFactor: 2.5, intervalDays: 300)
        let next = schedule(state, .easy)
        #expect(next.intervalDays == SRSConstants.maximumIntervalDays)
    }

    @Test("Интервал не опускается ниже одного дня")
    func intervalFloor() {
        let state = SRSState(state: .review, easeFactor: 1.3, intervalDays: 0.5)
        let next = schedule(state, .hard)
        #expect(next.intervalDays == SRSConstants.minimumReviewIntervalDays)
    }

    // MARK: - relearning

    @Test("relearning + again оставляет шаг 0 и переносит на десять минут")
    func relearningAgain() {
        let state = SRSState(state: .relearning, storedIntervalDays: 15)
        let next = schedule(state, .again)
        #expect(next.state == .relearning)
        #expect(next.learningStepIndex == 0)
        #expect(seconds(next) == tenMinutes)
        #expect(next.storedIntervalDays == 15)
    }

    @Test(
        "relearning + hard/good возвращает сохранённый интервал",
        arguments: [ReviewGrade.hard, .good]
    )
    func relearningRestores(grade: ReviewGrade) {
        let state = SRSState(state: .relearning, storedIntervalDays: 15)
        let next = schedule(state, grade)
        #expect(next.state == .review)
        #expect(next.intervalDays == 15)
        #expect(next.storedIntervalDays == 0)
    }

    @Test("relearning + easy возвращает сохранённый интервал с бонусом 1.3")
    func relearningEasy() {
        let state = SRSState(state: .relearning, storedIntervalDays: 15)
        let next = schedule(state, .easy)
        #expect(next.state == .review)
        #expect(abs(next.intervalDays - 19.5) < 0.0001)
    }

    // MARK: - Разброс

    @Test("Разброс не выводит срок за пределы ±5 % от интервала")
    func fuzzStaysWithinBounds() {
        let state = SRSState(state: .review, easeFactor: 2.5, intervalDays: 10)
        for _ in 0..<200 {
            let next = SRSScheduler.schedule(progress: state, grade: .good, now: now)
            let days = next.dueDate.timeIntervalSince(now) / day
            #expect(days >= next.intervalDays * 0.95 - 0.0001)
            #expect(days <= next.intervalDays * 1.05 + 0.0001)
        }
    }

    @Test("Разброс не применяется к шагам обучения: они точны до секунды")
    func fuzzDoesNotTouchLearningSteps() {
        for _ in 0..<50 {
            let next = SRSScheduler.schedule(progress: SRSState(), grade: .good, now: now)
            #expect(next.dueDate.timeIntervalSince(now) == tenMinutes)
        }
    }

    @Test("Сохранённый интервал при максимуме остаётся в границах после возврата")
    func fuzzAtCeilingStaysBounded() {
        let state = SRSState(state: .relearning, storedIntervalDays: 400)
        let next = SRSScheduler.schedule(progress: state, grade: .easy, now: now)
        #expect(next.intervalDays == SRSConstants.maximumIntervalDays)
        let days = next.dueDate.timeIntervalSince(now) / day
        #expect(days <= SRSConstants.maximumIntervalDays * 1.05 + 0.0001)
    }

    // MARK: - Оценка по времени ответа (6.3)

    @Test(
        "Автоматические режимы маппят ответ в оценку",
        arguments: [
            (false, 1.0, ReviewGrade.again),
            (false, 30.0, .again),
            (true, 12.0, .hard),
            (true, 10.5, .hard),
            (true, 5.0, .good),
            (true, 3.0, .good),
            (true, 10.0, .good),
            (true, 2.9, .easy),
            (true, 0.5, .easy),
        ]
    )
    func gradeFromResponseTime(correct: Bool, time: TimeInterval, expected: ReviewGrade) {
        #expect(SRSConstants.grade(correct: correct, responseTime: time) == expected)
    }

    // MARK: - Подписи интервалов

    @Test("Кнопки новой карточки показывают 1 мин / 1 мин / 10 мин / 4 д")
    func previewLabelsForNewCard() {
        let labels = IntervalFormatter.previewLabels(for: SRSState(), now: now)
        #expect(labels[.again] == "1 мин")
        #expect(labels[.hard] == "1 мин")
        #expect(labels[.good] == "10 мин")
        #expect(labels[.easy] == "4 д")
    }

    @Test(
        "Интервал форматируется по величине",
        arguments: [
            (30.0, "<1 мин"),
            (60.0, "1 мин"),
            (600.0, "10 мин"),
            (7200.0, "2 ч"),
            (86_400.0, "1 д"),
            (4 * 86_400.0, "4 д"),
            (60 * 86_400.0, "2 мес"),
            (365 * 86_400.0, "1 г"),
        ]
    )
    func formatsInterval(seconds: TimeInterval, expected: String) {
        #expect(IntervalFormatter.shortLabel(for: seconds) == expected)
    }

    // MARK: - Мост к хранилищу

    @Test("Состояние переносится в WordProgress и обратно без потерь")
    func roundTripsThroughProgress() {
        let original = SRSState(
            state: .review,
            easeFactor: 2.15,
            intervalDays: 42,
            learningStepIndex: 1,
            dueDate: now,
            repetitions: 7,
            lapses: 3,
            storedIntervalDays: 21
        )
        let progress = WordProgress()
        original.apply(to: progress)
        #expect(SRSState(progress: progress) == original)
    }
}
