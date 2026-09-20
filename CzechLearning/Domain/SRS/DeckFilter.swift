//
//  DeckFilter.swift
//  CzechVocab / Domain / SRS
//
//  Что попадает в сессию: уровни, темы, фразы, «только трудные» (ТЗ 6.5).
//

import Foundation

nonisolated struct DeckFilter: Sendable, Equatable {

    /// Пустое множество означает «все уровни».
    var levels: Set<CEFRLevel>
    /// Пустое множество означает «все категории».
    var categories: Set<String>
    var includePhrases: Bool
    /// Только слова, которые даются трудно: `lapses >= 2` либо доля верных
    /// ниже 60 % при четырёх и более ответах.
    var onlyDifficult: Bool

    init(
        levels: Set<CEFRLevel> = [],
        categories: Set<String> = [],
        includePhrases: Bool = true,
        onlyDifficult: Bool = false
    ) {
        self.levels = levels
        self.categories = categories
        self.includePhrases = includePhrases
        self.onlyDifficult = onlyDifficult
    }

    /// Весь словарь без ограничений.
    static let all = DeckFilter()

    /// Колода одного уровня.
    static func level(_ level: CEFRLevel) -> DeckFilter {
        DeckFilter(levels: [level])
    }

    /// Колода «Трудные слова» с главного экрана.
    static let difficult = DeckFilter(onlyDifficult: true)

    /// Колода одной темы каталога.
    static func category(_ category: String) -> DeckFilter {
        DeckFilter(categories: [category])
    }

    func matches(_ candidate: QueueCandidate) -> Bool {
        if !levels.isEmpty, !levels.contains(candidate.level) { return false }
        if !categories.isEmpty, !categories.contains(candidate.category) { return false }
        if !includePhrases, candidate.isPhrase { return false }
        if onlyDifficult, !candidate.isDifficult { return false }
        return true
    }
}
