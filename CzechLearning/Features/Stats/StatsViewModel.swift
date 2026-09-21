//
//  StatsViewModel.swift
//  CzechVocab / Features / Stats
//
//  Сводка прогресса: четыре плитки, активность за 30 дней, разбивка
//  по уровням и категориям.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StatsViewModel {

    /// Столбец графика активности.
    struct ActivityBar: Identifiable, Equatable {
        let day: Date
        let answers: Int

        var id: Date { day }
    }

    /// Строка разбивки по уровню или категории.
    struct Breakdown: Identifiable, Equatable {
        let title: String
        let learned: Int
        let total: Int

        var id: String { title }
        var share: Double { total > 0 ? Double(learned) / Double(total) : 0 }
    }

    /// Сколько дней показывает график (ТЗ 8.3).
    static let activityDays = 30

    private(set) var learnedCount = 0
    private(set) var inProgressCount = 0
    private(set) var remainingNewCount = 0
    /// Средняя доля верных ответов по всем словам с ответами.
    private(set) var averageAccuracy: Double = 0

    private(set) var activity: [ActivityBar] = []
    private(set) var levels: [Breakdown] = []
    private(set) var categories: [Breakdown] = []

    private let repository: WordRepository
    private let statsRepository: StatsRepository

    init(repository: WordRepository, statsRepository: StatsRepository) {
        self.repository = repository
        self.statsRepository = statsRepository
    }

    /// Максимум за период — по нему красятся столбцы графика.
    var activityMaximum: Int {
        activity.map(\.answers).max() ?? 0
    }

    func refresh(now: Date = .now) throws {
        let words = try repository.allWords()

        var learned = 0
        var inProgress = 0
        var untouched = 0
        var totalReviews = 0
        var correctReviews = 0

        var levelTotals: [CEFRLevel: Int] = [:]
        var levelLearned: [CEFRLevel: Int] = [:]
        var categoryTotals: [String: Int] = [:]
        var categoryLearned: [String: Int] = [:]

        for word in words {
            levelTotals[word.level, default: 0] += 1
            categoryTotals[word.category, default: 0] += 1

            guard let progress = word.progress, progress.state != .new else {
                untouched += 1
                continue
            }

            if progress.isLearned {
                learned += 1
                levelLearned[word.level, default: 0] += 1
                categoryLearned[word.category, default: 0] += 1
            } else {
                inProgress += 1
            }

            totalReviews += progress.totalReviews
            correctReviews += progress.correctReviews
        }

        learnedCount = learned
        inProgressCount = inProgress
        remainingNewCount = untouched
        averageAccuracy = totalReviews > 0 ? Double(correctReviews) / Double(totalReviews) : 0

        levels = CEFRLevel.allCases.map { level in
            Breakdown(
                title: level.rawValue,
                learned: levelLearned[level] ?? 0,
                total: levelTotals[level] ?? 0
            )
        }

        // По проценту освоения — чтобы сверху было видно, где продвинулись.
        categories = categoryTotals.keys
            .map { name in
                Breakdown(
                    title: name,
                    learned: categoryLearned[name] ?? 0,
                    total: categoryTotals[name] ?? 0
                )
            }
            .sorted { lhs, rhs in
                lhs.share == rhs.share ? lhs.title < rhs.title : lhs.share > rhs.share
            }

        activity = try statsRepository
            .recentStats(days: Self.activityDays, now: now)
            .map { ActivityBar(day: $0.day, answers: $0.reviewsCompleted) }
    }
}
