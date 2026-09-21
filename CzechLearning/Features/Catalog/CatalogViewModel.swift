//
//  CatalogViewModel.swift
//  CzechVocab / Features / Catalog
//
//  Каталог: поиск с дебаунсом, фильтр по уровню, разделы по темам.
//
//  Поиск идёт по нормализованным строкам в памяти, а не предикатом SwiftData:
//  1744 записи фильтруются за доли миллисекунды, зато можно искать по
//  `searchKey` (без диакритики), русскому и украинскому одним проходом.
//

import Foundation
import Observation

@MainActor
@Observable
final class CatalogViewModel {

    /// Раздел списка: тема, фразы или ложные друзья.
    struct Section: Identifiable, Hashable {
        enum Kind: Hashable {
            case category(String)
            case phrases
            case falseFriends
        }

        let kind: Kind
        let title: String
        let total: Int
        let learned: Int
        let symbolName: String

        var id: String {
            switch kind {
            case .category(let name): "category.\(name)"
            case .phrases: "phrases"
            case .falseFriends: "falseFriends"
            }
        }

        var share: Double { total > 0 ? Double(learned) / Double(total) : 0 }
    }

    // MARK: - Состояние

    var searchText = "" {
        didSet { scheduleSearch() }
    }

    var levelFilter: CEFRLevel? {
        didSet { rebuild() }
    }

    private(set) var sections: [Section] = []
    private(set) var results: [Word] = []
    private(set) var isSearching = false

    /// Дебаунс живого поиска (ТЗ 8.2).
    static let searchDebounce = Duration.milliseconds(300)

    private let repository: WordRepository
    private var allWords: [Word] = []
    /// Предрассчитанные ключи поиска: нормализация 1744 строк на каждое нажатие
    /// клавиши была бы заметной.
    private var searchIndex: [Int: String] = [:]
    private var searchTask: Task<Void, Never>?

    init(repository: WordRepository) {
        self.repository = repository
    }

    // MARK: - Загрузка

    func load() throws {
        allWords = try repository.allWords()
        searchIndex = Dictionary(
            uniqueKeysWithValues: allWords.map { ($0.id, Self.indexKey(for: $0)) }
        )
        rebuild()
    }

    /// Строка, по которой ищем: чешский без диакритики плюс оба перевода.
    private static func indexKey(for word: Word) -> String {
        [
            word.searchKey,
            TextNormalization.foldDiacritics(word.czech),
            word.russian.lowercased(),
            word.ukrainian.lowercased(),
        ].joined(separator: " ")
    }

    // MARK: - Поиск

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchText

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            isSearching = false
            results = []
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDebounce)
            guard !Task.isCancelled else { return }
            self?.performSearch(query)
        }
    }

    /// Синхронный поиск без дебаунса — для тестов и для мгновенного обновления
    /// при смене фильтра уровня.
    func performSearch(_ query: String) {
        let needle = TextNormalization.foldDiacritics(query)
            .trimmingCharacters(in: .whitespaces)

        guard !needle.isEmpty else {
            results = []
            isSearching = false
            return
        }

        results = filteredByLevel(allWords)
            .filter { searchIndex[$0.id]?.contains(needle) ?? false }
            .sorted(by: Self.relevance(needle: needle))
        isSearching = true
    }

    /// Точное совпадение чешского слова — выше остальных, дальше по алфавиту.
    private static func relevance(needle: String) -> (Word, Word) -> Bool {
        { lhs, rhs in
            let leftExact = lhs.searchKey == needle
            let rightExact = rhs.searchKey == needle
            if leftExact != rightExact { return leftExact }

            let leftPrefix = lhs.searchKey.hasPrefix(needle)
            let rightPrefix = rhs.searchKey.hasPrefix(needle)
            if leftPrefix != rightPrefix { return leftPrefix }

            return lhs.id < rhs.id
        }
    }

    // MARK: - Разделы

    private func rebuild() {
        if isSearching {
            performSearch(searchText)
        }
        sections = buildSections()
    }

    private func buildSections() -> [Section] {
        let words = filteredByLevel(allWords)

        var totals: [String: Int] = [:]
        var learned: [String: Int] = [:]
        var phraseTotal = 0
        var phraseLearned = 0
        var noteTotal = 0
        var noteLearned = 0

        for word in words {
            let isLearned = word.progress?.isLearned == true

            if word.isPhrase {
                phraseTotal += 1
                if isLearned { phraseLearned += 1 }
            } else {
                totals[word.category, default: 0] += 1
                if isLearned { learned[word.category, default: 0] += 1 }
            }
            if word.noteText != nil {
                noteTotal += 1
                if isLearned { noteLearned += 1 }
            }
        }

        var result: [Section] = []

        if phraseTotal > 0 {
            result.append(
                Section(
                    kind: .phrases,
                    title: String(localized: "Фразы"),
                    total: phraseTotal,
                    learned: phraseLearned,
                    symbolName: "text.bubble.fill"
                )
            )
        }
        if noteTotal > 0 {
            result.append(
                Section(
                    kind: .falseFriends,
                    title: String(localized: "Ложные друзья"),
                    total: noteTotal,
                    learned: noteLearned,
                    symbolName: "exclamationmark.triangle.fill"
                )
            )
        }

        result += totals.keys.sorted().map { category in
            Section(
                kind: .category(category),
                title: category,
                total: totals[category] ?? 0,
                learned: learned[category] ?? 0,
                symbolName: "folder.fill"
            )
        }
        return result
    }

    // MARK: - Содержимое раздела

    func words(in section: Section) -> [Word] {
        let words = filteredByLevel(allWords)
        return switch section.kind {
        case .category(let name): words.filter { !$0.isPhrase && $0.category == name }
        case .phrases: words.filter(\.isPhrase)
        case .falseFriends: words.filter { $0.noteText != nil }
        }
    }

    /// Ситуации внутри раздела «Фразы»: 15 категорий вида «Фразы: …».
    func phraseSituations() -> [String] {
        Set(allWords.filter(\.isPhrase).map(\.category)).sorted()
    }

    private func filteredByLevel(_ words: [Word]) -> [Word] {
        guard let levelFilter else { return words }
        return words.filter { $0.level == levelFilter }
    }
}
