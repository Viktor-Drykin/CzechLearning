//
//  HomeViewModel.swift
//  CzechVocab / Features / Home
//
//  Сводка для главного экрана: сколько к повторению и новых на сегодня,
//  прогресс колод по уровням, счётчик трудных слов.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class HomeViewModel {

    struct DeckSummary: Identifiable, Equatable {
        let level: CEFRLevel
        let total: Int
        let learned: Int

        var id: String { level.rawValue }
        var share: Double { total > 0 ? Double(learned) / Double(total) : 0 }
    }

    private(set) var dueCount = 0
    private(set) var newCount = 0
    private(set) var learningCount = 0
    private(set) var difficultCount = 0
    private(set) var decks: [DeckSummary] = []
    /// Новых слов ещё не показано вовсе — вообще есть что учить вперёд.
    private(set) var hasUnseenWords = false

    private let repository: WordRepository
    private let statsRepository: StatsRepository
    private let settings: SettingsStore

    init(repository: WordRepository, statsRepository: StatsRepository, settings: SettingsStore) {
        self.repository = repository
        self.statsRepository = statsRepository
        self.settings = settings
    }

    var hasWorkToday: Bool {
        dueCount > 0 || newCount > 0
    }

    func refresh(now: Date = .now) throws {
        let candidates = try repository.queueCandidates()
        let studiedToday = try statsRepository.stats(for: now).newCardsStudied

        let active = candidates.filter { !$0.isSuspended }

        dueCount = active.filter {
            $0.state != .new && ($0.dueDate ?? .distantPast) <= now
        }.count
        learningCount = active.filter {
            $0.state == .learning || $0.state == .relearning
        }.count
        difficultCount = active.filter(\.isDifficult).count

        let unseen = active.filter(\.isNew)
        hasUnseenWords = !unseen.isEmpty

        let budget = settings.newCardsPerDay == SRSConstants.unlimited
            ? unseen.count
            : max(0, settings.newCardsPerDay - studiedToday)
        newCount = min(budget, unseen.count)

        decks = try deckSummaries()
    }

    private func deckSummaries() throws -> [DeckSummary] {
        var totals: [CEFRLevel: Int] = [:]
        var learned: [CEFRLevel: Int] = [:]

        for word in try repository.allWords() {
            totals[word.level, default: 0] += 1
            if word.progress?.isLearned == true {
                learned[word.level, default: 0] += 1
            }
        }

        return CEFRLevel.allCases.map { level in
            DeckSummary(
                level: level,
                total: totals[level] ?? 0,
                learned: learned[level] ?? 0
            )
        }
    }
}
