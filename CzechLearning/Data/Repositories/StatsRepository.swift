//
//  StatsRepository.swift
//  CzechVocab / Data / Repositories
//
//  Дневные агрегаты и сводка для экрана прогресса.
//

import Foundation
import SwiftData

@MainActor
struct StatsRepository {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Дневная статистика

    /// Агрегат за день, создаётся при первом ответе в этот день.
    @discardableResult
    func stats(for date: Date = .now) throws -> DailyStats {
        let key = DailyStats.dayKey(for: date)
        var descriptor = FetchDescriptor<DailyStats>(predicate: #Predicate { $0.day == key })
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first { return existing }
        let created = DailyStats(day: key)
        context.insert(created)
        return created
    }

    /// Учитывает один ответ в дневном агрегате.
    func recordAnswer(
        wasNew: Bool,
        correct: Bool,
        date: Date = .now
    ) throws {
        let stats = try stats(for: date)
        stats.reviewsCompleted += 1
        if wasNew { stats.newCardsStudied += 1 }
        if correct { stats.correctCount += 1 }
    }

    /// Добавляет время, проведённое в сессии.
    func recordStudyTime(_ seconds: Int, date: Date = .now) throws {
        guard seconds > 0 else { return }
        try stats(for: date).studyTimeSeconds += seconds
    }

    /// Агрегаты за последние `days` дней, по одному на день, включая пустые:
    /// график активности рисует и дни без ответов.
    func recentStats(days: Int, now: Date = .now, calendar: Calendar = .current) throws -> [DailyStats] {
        let today = calendar.startOfDay(for: now)
        guard let earliest = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }

        let stored = try context.fetch(
            FetchDescriptor<DailyStats>(
                predicate: #Predicate { $0.day >= earliest },
                sortBy: [SortDescriptor(\.day)]
            )
        )
        let byDay = Dictionary(stored.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })

        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: earliest) else {
                return nil
            }
            return byDay[day] ?? DailyStats(day: day)
        }
    }

    // MARK: - Сброс

    /// Полный сброс прогресса: состояния, журнал и дневные агрегаты.
    /// Словарь остаётся — переимпортировать его незачем.
    func resetAllProgress() throws {
        try context.delete(model: WordProgress.self)
        try context.delete(model: ReviewLog.self)
        try context.delete(model: DailyStats.self)
        try context.save()
    }
}
