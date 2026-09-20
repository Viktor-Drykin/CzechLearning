//
//  QueueBuilder.swift
//  CzechVocab / Domain / SRS
//
//  Очередь на день (ТЗ 6.4). Работает со снимками, а не с моделями SwiftData:
//  так порядок и лимиты проверяются юнит-тестами без контейнера, а репозиторий
//  остаётся тонким.
//

import Foundation

// MARK: - Кандидат

/// Снимок слова, достаточный для отбора в очередь.
nonisolated struct QueueCandidate: Sendable, Equatable, Identifiable {

    let id: Int
    let level: CEFRLevel
    let category: String
    let isPhrase: Bool
    let state: CardState
    /// `nil` у слов, которые ещё ни разу не показывались.
    let dueDate: Date?
    let lapses: Int
    let totalReviews: Int
    let correctReviews: Int
    let isSuspended: Bool

    init(
        id: Int,
        level: CEFRLevel,
        category: String,
        isPhrase: Bool,
        state: CardState = .new,
        dueDate: Date? = nil,
        lapses: Int = 0,
        totalReviews: Int = 0,
        correctReviews: Int = 0,
        isSuspended: Bool = false
    ) {
        self.id = id
        self.level = level
        self.category = category
        self.isPhrase = isPhrase
        self.state = state
        self.dueDate = dueDate
        self.lapses = lapses
        self.totalReviews = totalReviews
        self.correctReviews = correctReviews
        self.isSuspended = isSuspended
    }

    /// Тот же критерий, что и у `WordProgress.isDifficult`.
    var isDifficult: Bool {
        if lapses >= SRSConstants.difficultLapseThreshold { return true }
        guard totalReviews >= SRSConstants.difficultMinimumReviews, totalReviews > 0 else {
            return false
        }
        return Double(correctReviews) / Double(totalReviews) < SRSConstants.difficultAccuracyThreshold
    }

    var isNew: Bool { state == .new }
}

// MARK: - Построитель

nonisolated struct QueueBuilder {

    /// Разбивка очереди для шапки сессии.
    struct Queue: Sendable, Equatable {
        var items: [QueueCandidate] = []
        var reviewCount = 0
        var newCount = 0
        var learningCount = 0

        var isEmpty: Bool { items.isEmpty }
        var count: Int { items.count }
        var wordIDs: [Int] { items.map(\.id) }
    }

    /// - Parameters:
    ///   - limitNew: сколько новых слов взять; `SRSConstants.unlimited` — без лимита.
    ///   - limitReviews: сколько повторений взять; `SRSConstants.unlimited` — без лимита.
    ///   - includeFutureNew: брать новые, даже если на сегодня повторений нет
    ///     (кнопка «Учить вперёд»); лимит при этом всё равно соблюдается.
    static func build(
        from candidates: [QueueCandidate],
        deck: DeckFilter = .all,
        limitNew: Int = SRSConstants.defaultNewCardsPerDay,
        limitReviews: Int = SRSConstants.defaultReviewsPerDay,
        now: Date = .now
    ) -> Queue {
        let eligible = candidates.filter { !$0.isSuspended && deck.matches($0) }

        // Повторения: срок наступил, состояние не «новое». Сортировка по сроку.
        let due = eligible
            .filter { $0.state != .new && ($0.dueDate ?? .distantPast) <= now }
            .sorted { lhs, rhs in
                let left = lhs.dueDate ?? .distantPast
                let right = rhs.dueDate ?? .distantPast
                return left == right ? lhs.id < rhs.id : left < right
            }
            .prefix(limited(limitReviews))

        // Новые: по уровню, затем по id — данных о частотности нет (ТЗ 16.3).
        let fresh = eligible
            .filter(\.isNew)
            .sorted { lhs, rhs in
                lhs.level == rhs.level ? lhs.id < rhs.id : lhs.level < rhs.level
            }
            .prefix(limited(limitNew))

        var queue = Queue()
        queue.items = interleave(reviews: Array(due), newCards: Array(fresh))
        queue.reviewCount = due.count
        queue.newCount = fresh.count
        queue.learningCount = due.filter { $0.state == .learning || $0.state == .relearning }.count
        return queue
    }

    // MARK: - Перемешивание

    /// Раскладывает новые карточки равномерно между повторениями, чтобы они
    /// не шли блоком (ТЗ 6.4, п. 3). Порядок повторений по сроку сохраняется.
    static func interleave(
        reviews: [QueueCandidate],
        newCards: [QueueCandidate]
    ) -> [QueueCandidate] {
        guard !newCards.isEmpty else { return reviews }
        guard !reviews.isEmpty else { return newCards }

        var result = reviews
        // Вставляем с конца, иначе ранние вставки сдвигают вычисленные позиции.
        for index in stride(from: newCards.count - 1, through: 0, by: -1) {
            let share = Double(index + 1) / Double(newCards.count + 1)
            let position = Int((share * Double(reviews.count)).rounded())
            result.insert(newCards[index], at: min(position, result.count))
        }
        return result
    }

    // MARK: - Служебное

    /// `prefix` не принимает `Int.max` как «без лимита» — приводим к размеру данных.
    private static func limited(_ limit: Int) -> Int {
        max(0, limit)
    }
}
