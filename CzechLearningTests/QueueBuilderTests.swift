//
//  QueueBuilderTests.swift
//  CzechLearningTests
//

import Foundation
import Testing

@testable import CzechLearning

@Suite("Очередь на день")
struct QueueBuilderTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func newCard(
        _ id: Int,
        level: CEFRLevel = .a1,
        category: String = "Еда",
        isPhrase: Bool = false,
        suspended: Bool = false
    ) -> QueueCandidate {
        QueueCandidate(
            id: id,
            level: level,
            category: category,
            isPhrase: isPhrase,
            state: .new,
            isSuspended: suspended
        )
    }

    private func review(
        _ id: Int,
        dueIn minutes: Double,
        level: CEFRLevel = .a1,
        category: String = "Еда",
        state: CardState = .review,
        lapses: Int = 0,
        total: Int = 0,
        correct: Int = 0,
        suspended: Bool = false
    ) -> QueueCandidate {
        QueueCandidate(
            id: id,
            level: level,
            category: category,
            isPhrase: false,
            state: state,
            dueDate: now.addingTimeInterval(minutes * 60),
            lapses: lapses,
            totalReviews: total,
            correctReviews: correct,
            isSuspended: suspended
        )
    }

    // MARK: - Отбор

    @Test("В очередь попадают только карточки с наступившим сроком")
    func onlyDueReviews() {
        let queue = QueueBuilder.build(
            from: [review(1, dueIn: -60), review(2, dueIn: 60), review(3, dueIn: 0)],
            limitNew: 0,
            now: now
        )
        #expect(queue.wordIDs == [1, 3])
        #expect(queue.reviewCount == 2)
    }

    @Test("Повторения идут по возрастанию срока")
    func reviewsSortedByDueDate() {
        let queue = QueueBuilder.build(
            from: [review(1, dueIn: -10), review(2, dueIn: -100), review(3, dueIn: -50)],
            limitNew: 0,
            now: now
        )
        #expect(queue.wordIDs == [2, 3, 1])
    }

    @Test("Новые сортируются по уровню, затем по id")
    func newSortedByLevelThenID() {
        let queue = QueueBuilder.build(
            from: [
                newCard(30, level: .b1),
                newCard(10, level: .a2),
                newCard(5, level: .b1),
                newCard(20, level: .a1),
                newCard(1, level: .a2),
            ],
            limitNew: SRSConstants.unlimited,
            limitReviews: 0,
            now: now
        )
        #expect(queue.wordIDs == [20, 1, 10, 5, 30])
    }

    @Test("Приостановленные слова не попадают в очередь")
    func skipsSuspended() {
        let queue = QueueBuilder.build(
            from: [review(1, dueIn: -10, suspended: true), newCard(2, suspended: true), review(3, dueIn: -10)],
            limitNew: 10,
            now: now
        )
        #expect(queue.wordIDs == [3])
    }

    // MARK: - Лимиты

    @Test("Лимит новых соблюдается")
    func respectsNewLimit() {
        let cards = (1...30).map { newCard($0) }
        let queue = QueueBuilder.build(from: cards, limitNew: 10, limitReviews: 0, now: now)
        #expect(queue.newCount == 10)
        #expect(queue.count == 10)
        #expect(queue.wordIDs == Array(1...10))
    }

    @Test("Лимит повторений соблюдается и отрезает самые поздние сроки")
    func respectsReviewLimit() {
        let cards = (1...50).map { review($0, dueIn: Double(-$0)) }
        let queue = QueueBuilder.build(from: cards, limitNew: 0, limitReviews: 20, now: now)
        #expect(queue.reviewCount == 20)
        // Самый ранний срок у id 50, дальше по убыванию номера.
        #expect(queue.wordIDs.first == 50)
        #expect(queue.wordIDs.count == 20)
    }

    @Test("Без лимита берутся все подходящие карточки")
    func unlimited() {
        let cards = (1...300).map { newCard($0) }
        let queue = QueueBuilder.build(
            from: cards,
            limitNew: SRSConstants.unlimited,
            limitReviews: SRSConstants.unlimited,
            now: now
        )
        #expect(queue.count == 300)
    }

    @Test("Нулевые лимиты дают пустую очередь")
    func zeroLimits() {
        let queue = QueueBuilder.build(
            from: [newCard(1), review(2, dueIn: -10)],
            limitNew: 0,
            limitReviews: 0,
            now: now
        )
        #expect(queue.isEmpty)
    }

    // MARK: - Фильтр колоды

    @Test("Фильтр по уровню отсекает чужие уровни")
    func filtersByLevel() {
        let queue = QueueBuilder.build(
            from: [newCard(1, level: .a1), newCard(2, level: .a2), newCard(3, level: .b1)],
            deck: .level(.a2),
            limitNew: 10,
            now: now
        )
        #expect(queue.wordIDs == [2])
    }

    @Test("Фильтр по категории отсекает чужие темы")
    func filtersByCategory() {
        let queue = QueueBuilder.build(
            from: [newCard(1, category: "Еда"), newCard(2, category: "Транспорт")],
            deck: .category("Транспорт"),
            limitNew: 10,
            now: now
        )
        #expect(queue.wordIDs == [2])
    }

    @Test("Пустой фильтр пропускает все уровни и категории")
    func emptyFilterMatchesEverything() {
        let queue = QueueBuilder.build(
            from: [newCard(1, level: .a1, category: "Еда"), newCard(2, level: .b1, category: "Работа")],
            deck: .all,
            limitNew: 10,
            now: now
        )
        #expect(queue.count == 2)
    }

    @Test("Фразы исключаются, когда includePhrases выключен")
    func excludesPhrases() {
        let queue = QueueBuilder.build(
            from: [newCard(1), newCard(2, isPhrase: true)],
            deck: DeckFilter(includePhrases: false),
            limitNew: 10,
            now: now
        )
        #expect(queue.wordIDs == [1])
    }

    @Test("onlyDifficult берёт слова с двумя провалами или низкой долей верных")
    func filtersDifficult() {
        let candidates = [
            review(1, dueIn: -10, lapses: 2),                        // по провалам
            review(2, dueIn: -10, lapses: 0, total: 5, correct: 2),  // 40 % верных
            review(3, dueIn: -10, lapses: 1, total: 5, correct: 4),  // 80 % — не трудное
            review(4, dueIn: -10, lapses: 1, total: 3, correct: 0),  // мало ответов
        ]
        let queue = QueueBuilder.build(
            from: candidates,
            deck: .difficult,
            limitNew: 0,
            now: now
        )
        #expect(Set(queue.wordIDs) == [1, 2])
    }

    @Test("Ровно 60 % верных — ещё не трудное слово")
    func difficultThresholdIsStrict() {
        let borderline = review(1, dueIn: -10, total: 5, correct: 3)
        #expect(borderline.isDifficult == false)
        let below = review(2, dueIn: -10, total: 5, correct: 2)
        #expect(below.isDifficult)
    }

    // MARK: - Смешивание

    @Test("Новые не идут блоком, а распределяются между повторениями")
    func newCardsAreSpreadOut() {
        let reviews = (1...20).map { review($0, dueIn: Double(-$0)) }
        let fresh = (101...105).map { newCard($0) }
        let queue = QueueBuilder.build(from: reviews + fresh, limitNew: 5, limitReviews: 20, now: now)

        #expect(queue.count == 25)

        let positions = queue.items.enumerated()
            .filter { $0.element.isNew }
            .map(\.offset)
        #expect(positions.count == 5)

        // Ни одной пары новых подряд и ни одной в самом начале блоком.
        let gaps = zip(positions, positions.dropFirst()).map { $1 - $0 }
        #expect(gaps.allSatisfy { $0 >= 2 }, "Новые встали подряд: \(positions)")
        #expect(positions.last ?? 0 < queue.count - 1)
    }

    @Test("Порядок повторений между вставленными новыми не ломается")
    func interleavingKeepsReviewOrder() {
        let reviews = (1...10).map { review($0, dueIn: Double(-100 + $0)) }
        let fresh = (101...103).map { newCard($0) }
        let queue = QueueBuilder.build(from: reviews + fresh, limitNew: 3, limitReviews: 10, now: now)

        let reviewIDs = queue.items.filter { !$0.isNew }.map(\.id)
        #expect(reviewIDs == Array(1...10))
    }

    @Test("Только новые или только повторения — очередь не ломается")
    func handlesSingleSidedQueues() {
        let onlyNew = QueueBuilder.build(from: (1...5).map { newCard($0) }, limitNew: 5, now: now)
        #expect(onlyNew.count == 5)
        #expect(onlyNew.reviewCount == 0)

        let onlyReviews = QueueBuilder.build(
            from: (1...5).map { review($0, dueIn: -10) },
            limitNew: 0,
            now: now
        )
        #expect(onlyReviews.count == 5)
        #expect(onlyReviews.newCount == 0)
    }

    // MARK: - Разбивка для шапки

    @Test("Разбивка считает повторения, новые и карточки в изучении")
    func countsBreakdown() {
        let candidates = [
            review(1, dueIn: -10, state: .review),
            review(2, dueIn: -10, state: .learning),
            review(3, dueIn: -10, state: .relearning),
            newCard(4),
        ]
        let queue = QueueBuilder.build(from: candidates, limitNew: 10, now: now)
        #expect(queue.reviewCount == 3)
        #expect(queue.learningCount == 2)
        #expect(queue.newCount == 1)
        #expect(queue.count == 4)
    }
}
