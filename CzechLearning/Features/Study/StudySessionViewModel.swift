//
//  StudySessionViewModel.swift
//  CzechVocab / Features / Study
//
//  Состояние одной сессии: очередь, текущая карточка, запись ответа,
//  внутрисессионное повторение и итоги.
//
//  Карточка, отвеченная `again` (или иначе оставшаяся в learning/relearning
//  со сроком внутри сессии), возвращается в конец очереди — критерий приёмки
//  из раздела 15 ТЗ.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StudySessionViewModel {

    // MARK: - Итоги

    struct Summary: Equatable {
        var answered = 0
        var correct = 0
        var newLearned = 0
        var duration: TimeInterval = 0

        var accuracy: Double {
            answered > 0 ? Double(correct) / Double(answered) : 0
        }
    }

    // MARK: - Состояние

    /// Слова в порядке показа. Пересобирается при внутрисессионном повторении.
    private(set) var queue: [Word] = []
    private(set) var currentIndex = 0
    private(set) var summary = Summary()
    private(set) var isFinished = false

    /// Снимок словаря для генерации вариантов ответа. Заполняется только
    /// в режимах, где варианты нужны.
    private(set) var dictionary: [DistractorCandidate] = []

    /// Разбивка исходной очереди для шапки.
    private(set) var initialReviewCount = 0
    private(set) var initialNewCount = 0
    private(set) var initialLearningCount = 0

    /// Сколько карточек было в очереди на старте: прогресс-бар считает от него,
    /// иначе возвращённые карточки дёргали бы полосу назад.
    private(set) var plannedCount = 0

    let mode: StudyMode
    let deck: DeckFilter

    private let repository: WordRepository
    private let statsRepository: StatsRepository
    private let settings: SettingsStore
    private let startedAt: Date

    /// Слова, которые на старте сессии были новыми: нужны для счётчика
    /// «выучено новых» и дневной статистики.
    private var wasNewAtStart: Set<Int> = []
    /// Когда показана текущая карточка — для оценки по времени ответа.
    private var cardShownAt = Date.now
    /// Направление показа текущей карточки: `mixed` разворачивается один раз.
    private(set) var currentDirection: CardDirection = .czechToTranslation

    // MARK: - Инициализация

    init(
        mode: StudyMode,
        deck: DeckFilter,
        repository: WordRepository,
        statsRepository: StatsRepository,
        settings: SettingsStore,
        now: Date = .now
    ) {
        self.mode = mode
        self.deck = deck
        self.repository = repository
        self.statsRepository = statsRepository
        self.settings = settings
        startedAt = now
    }

    // MARK: - Загрузка очереди

    /// - Parameter aheadOfSchedule: «Учить вперёд» — дневной лимит новых
    ///   отсчитывается заново, даже если он уже выбран сегодня.
    func loadQueue(aheadOfSchedule: Bool = false, now: Date = .now) throws {
        let candidates = try repository.queueCandidates()

        let built = QueueBuilder.build(
            from: candidates,
            deck: deck,
            limitNew: try newCardBudget(aheadOfSchedule: aheadOfSchedule, now: now),
            limitReviews: settings.reviewsPerDay,
            now: now
        )

        // В письменном вводе фразы пропускаются: набирать их слишком долго (ТЗ 7.3).
        let items = mode == .typing ? built.items.filter { !$0.isPhrase } : built.items

        queue = try repository.words(ids: items.map(\.id))
        // Словарь для дистракторов — один снимок на сессию: пересобирать его
        // на каждую карточку значило бы читать 1744 записи по пятьдесят раз.
        if mode == .multipleChoice || mode == .listening {
            dictionary = try repository.allWords().map(DistractorCandidate.init(word:))
        }
        plannedCount = queue.count
        currentIndex = 0
        initialReviewCount = built.reviewCount
        initialNewCount = built.newCount
        initialLearningCount = built.learningCount
        wasNewAtStart = Set(items.filter(\.isNew).map(\.id))
        isFinished = queue.isEmpty
        resetCardTimer()
    }

    /// Сколько новых слов ещё можно взять сегодня: дневной лимит за вычетом уже пройденных.
    /// «Учить вперёд» выдаёт полный лимит заново.
    private func newCardBudget(aheadOfSchedule: Bool, now: Date) throws -> Int {
        let limit = settings.newCardsPerDay
        guard limit != SRSConstants.unlimited else { return limit }
        guard !aheadOfSchedule else { return limit }
        let studiedToday = try statsRepository.stats(for: now).newCardsStudied
        return max(0, limit - studiedToday)
    }

    // MARK: - Текущая карточка

    var currentWord: Word? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    /// Сколько карточек осталось, включая текущую.
    var remainingCount: Int {
        max(0, queue.count - currentIndex)
    }

    /// Доля пройденного от исходного размера очереди. Возвращённые карточки
    /// не увеличивают знаменатель: иначе полоса дёргалась бы назад при каждом
    /// «Снова». Сверху ограничена единицей.
    var progressValue: Double {
        guard plannedCount > 0 else { return isFinished ? 1 : 0 }
        return min(1, Double(currentIndex) / Double(plannedCount))
    }

    /// Пройдено меньше половины — закрытие сессии требует подтверждения (ТЗ 8.1).
    var needsCloseConfirmation: Bool {
        guard plannedCount > 0, !isFinished else { return false }
        return Double(currentIndex) / Double(plannedCount) < 0.5
    }

    /// Состояние SM-2 текущей карточки — для подписей интервалов на кнопках.
    func currentState() -> SRSState {
        guard let word = currentWord else { return SRSState() }
        return word.progress.map(SRSState.init(progress:)) ?? SRSState()
    }

    func intervalLabels(now: Date = .now) -> [ReviewGrade: String] {
        IntervalFormatter.previewLabels(for: currentState(), now: now)
    }

    /// Сколько прошло с момента показа карточки — для оценки в автоматических режимах.
    func elapsedSinceShown(now: Date = .now) -> TimeInterval {
        now.timeIntervalSince(cardShownAt)
    }

    // MARK: - Ответ

    /// Записывает оценку, двигает очередь и при необходимости возвращает карточку в конец.
    func submit(grade: ReviewGrade, now: Date = .now) {
        guard let word = currentWord else { return }

        let wasNew = wasNewAtStart.contains(word.id)
        let responseTime = now.timeIntervalSince(cardShownAt)

        do {
            try repository.recordAnswer(
                word: word,
                grade: grade,
                mode: mode,
                responseTime: responseTime,
                now: now
            )
            try statsRepository.recordAnswer(wasNew: wasNew, correct: grade != .again, date: now)
            try repository.save()
        } catch {
            // Ответ не сохранился — сессию не рвём, но и прогресс не выдумываем.
            assertionFailure("Не удалось записать ответ: \(error)")
        }

        summary.answered += 1
        if grade != .again {
            summary.correct += 1
        }
        if wasNew, word.progress?.state == .review {
            summary.newLearned += 1
        }

        advance(after: word, now: now)
    }

    /// Ответ автоматического режима: оценка считается по времени (ТЗ 6.3).
    func submitAutomatic(correct: Bool, now: Date = .now) {
        let grade = SRSConstants.grade(
            correct: correct,
            responseTime: now.timeIntervalSince(cardShownAt)
        )
        submit(grade: grade, now: now)
    }

    /// Ответ письменного режима: потолок оценки задаёт исход проверки.
    func submitTyped(outcome: AnswerValidator.Outcome, now: Date = .now) {
        let grade = AnswerValidator.grade(
            for: outcome,
            responseTime: now.timeIntervalSince(cardShownAt)
        )
        submit(grade: grade, now: now)
    }

    // MARK: - Режим «Пары»

    /// Пять слов из головы очереди для очередного раунда.
    func matchingRound() -> [MatchingWord] {
        queue[currentIndex...]
            .prefix(MatchingRoundBuilder.pairCount)
            .map(MatchingWord.init(word:))
    }

    /// Результат по одной паре. Верная — `good`, промах — `hard`.
    /// Оценка идёт в SRS, но карточка при этом не покидает очередь:
    /// её двигает завершение раунда.
    func recordPair(wordID: Int, grade: ReviewGrade, now: Date = .now) {
        guard let word = queue.first(where: { $0.id == wordID }) else { return }
        let wasNew = wasNewAtStart.contains(wordID)

        do {
            try repository.recordAnswer(
                word: word,
                grade: grade,
                mode: .matching,
                responseTime: now.timeIntervalSince(cardShownAt),
                now: now
            )
            try statsRepository.recordAnswer(wasNew: wasNew, correct: grade != .again, date: now)
            try repository.save()
        } catch {
            assertionFailure("Не удалось записать пару: \(error)")
        }

        summary.answered += 1
        if grade != .again {
            summary.correct += 1
        }
        if wasNew, word.progress?.state == .review {
            summary.newLearned += 1
        }
    }

    /// Раунд собран — сдвигаем очередь на его длину.
    func finishMatchingRound() {
        currentIndex += min(MatchingRoundBuilder.pairCount, remainingCount)
        finishIfNeeded()
        resetCardTimer()
    }

    /// Пропуск карточки без записи ответа — например, фраза в письменном вводе.
    func skipCurrent() {
        guard currentWord != nil else { return }
        currentIndex += 1
        finishIfNeeded()
        resetCardTimer()
    }

    // MARK: - Движение по очереди

    private func advance(after word: Word, now: Date) {
        currentIndex += 1

        // Карточка вернулась в изучение и её срок наступает внутри сессии —
        // показываем ещё раз в конце (ТЗ 6.4, п. 4).
        if shouldRepeatInSession(word, now: now) {
            queue.append(word)
        }

        finishIfNeeded()
        resetCardTimer()
    }

    private func shouldRepeatInSession(_ word: Word, now: Date) -> Bool {
        guard let progress = word.progress else { return false }
        guard progress.state == .learning || progress.state == .relearning else { return false }
        // Дальние сроки оставляем следующей сессии: внутри текущей их не дождаться.
        return progress.dueDate.timeIntervalSince(now) <= Self.inSessionRepeatWindow
    }

    private func finishIfNeeded() {
        guard currentIndex >= queue.count else { return }
        isFinished = true
        summary.duration = Date.now.timeIntervalSince(startedAt)
        try? statsRepository.recordStudyTime(Int(summary.duration))
        try? repository.save()
    }

    private func resetCardTimer() {
        cardShownAt = .now
        currentDirection = settings.cardDirection.resolved()
    }

    /// Срок в пределах этого окна считается «внутри сессии».
    private static let inSessionRepeatWindow: TimeInterval = 20 * 60
}
