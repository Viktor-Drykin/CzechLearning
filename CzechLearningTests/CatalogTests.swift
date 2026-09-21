//
//  CatalogTests.swift
//  CzechLearningTests
//
//  Поиск и разделы каталога на полном словаре — критерий приёмки этапа 4:
//  `pozor` находится по `pozor`, `POZOR`, `внимание`, `увага`.
//

import Foundation
import SwiftData
import Testing

@testable import CzechLearning

@Suite("Каталог")
@MainActor
struct CatalogTests {

    private func makeCatalog() async throws -> (CatalogViewModel, ModelContext) {
        let container = try AppSchema.makeInMemoryContainer()
        let importer = DataImporter(modelContainer: container)
        _ = try await importer.importVocabulary(from: VocabularyResource.url())

        let context = ModelContext(container)
        let catalog = CatalogViewModel(repository: WordRepository(context: context))
        try catalog.load()
        return (catalog, context)
    }

    // MARK: - Поиск

    @Test(
        "Слово pozor находится по чешскому, русскому и украинскому запросу",
        arguments: ["pozor", "POZOR", "Pozor", "внимание", "увага", "ВНИМАНИЕ"]
    )
    func findsPozor(query: String) async throws {
        let (catalog, _) = try await makeCatalog()
        catalog.performSearch(query)

        #expect(catalog.results.contains { $0.czech == "pozor" }, "Запрос «\(query)»")
    }

    @Test("Поиск по чешскому работает и с диакритикой, и без неё")
    func findsWithAndWithoutDiacritics() async throws {
        let (catalog, _) = try await makeCatalog()

        catalog.performSearch("přítel")
        let withDiacritics = catalog.results.map(\.czech)

        catalog.performSearch("pritel")
        let without = catalog.results.map(\.czech)

        #expect(withDiacritics.contains("přítel"))
        #expect(without.contains("přítel"))
    }

    @Test("Точное совпадение чешского слова стоит первым")
    func exactMatchRanksFirst() async throws {
        let (catalog, _) = try await makeCatalog()
        catalog.performSearch("pozor")
        #expect(catalog.results.first?.czech == "pozor")
    }

    @Test("Пустой запрос не оставляет результатов поиска")
    func emptyQueryClearsResults() async throws {
        let (catalog, _) = try await makeCatalog()
        catalog.performSearch("pozor")
        #expect(!catalog.results.isEmpty)

        catalog.performSearch("   ")
        #expect(catalog.results.isEmpty)
        #expect(catalog.isSearching == false)
    }

    @Test("Заведомо отсутствующее слово ничего не находит")
    func missingWordFindsNothing() async throws {
        let (catalog, _) = try await makeCatalog()
        catalog.performSearch("qwertyuiop")
        #expect(catalog.results.isEmpty)
    }

    @Test("Фильтр уровня сужает поиск")
    func levelFilterNarrowsSearch() async throws {
        let (catalog, _) = try await makeCatalog()

        catalog.performSearch("a")
        let unfiltered = catalog.results.count

        catalog.levelFilter = .b1
        catalog.performSearch("a")

        #expect(catalog.results.count < unfiltered)
        #expect(catalog.results.allSatisfy { $0.level == .b1 })
    }

    // MARK: - Разделы

    @Test("Каталог показывает 57 тем, фразы и ложные друзья — отдельными разделами")
    func buildsSections() async throws {
        let (catalog, _) = try await makeCatalog()

        let phrases = try #require(catalog.sections.first { $0.kind == .phrases })
        #expect(phrases.total == 168)

        let falseFriends = try #require(catalog.sections.first { $0.kind == .falseFriends })
        #expect(falseFriends.total == 38)

        // Категорий в данных 57, но 14 из них состоят только из фраз и уезжают
        // в раздел «Фразы». Пятнадцатая фразовая ситуация — «Приветствия и
        // вежливость» — содержит и обычные слова, поэтому темой остаётся.
        let categories = catalog.sections.filter {
            if case .category = $0.kind { return true } else { return false }
        }
        #expect(categories.count == 43)
        #expect(categories.map(\.total).reduce(0, +) == 1576)
    }

    @Test("Раздел «Фразы» покрывает 15 ситуаций")
    func phraseSituations() async throws {
        let (catalog, _) = try await makeCatalog()
        #expect(catalog.phraseSituations().count == 15)
    }

    @Test("Содержимое раздела соответствует его типу")
    func sectionContents() async throws {
        let (catalog, _) = try await makeCatalog()

        let phrases = try #require(catalog.sections.first { $0.kind == .phrases })
        let phraseWords = catalog.words(in: phrases)
        #expect(phraseWords.count == 168)
        #expect(phraseWords.allSatisfy { $0.isPhrase })

        let falseFriends = try #require(catalog.sections.first { $0.kind == .falseFriends })
        let noted = catalog.words(in: falseFriends)
        #expect(noted.count == 38)
        #expect(noted.allSatisfy { $0.noteText != nil })
    }

    @Test("Фильтр уровня пересчитывает разделы")
    func levelFilterRebuildsSections() async throws {
        let (catalog, _) = try await makeCatalog()
        let allTotal = catalog.sections.filter {
            if case .category = $0.kind { return true } else { return false }
        }.map(\.total).reduce(0, +)

        catalog.levelFilter = .a1
        let a1Total = catalog.sections.filter {
            if case .category = $0.kind { return true } else { return false }
        }.map(\.total).reduce(0, +)

        #expect(a1Total < allTotal)
        #expect(catalog.words(in: catalog.sections[0]).allSatisfy { $0.level == .a1 })
    }

    // MARK: - Прогресс в разделах

    @Test("Выученные слова попадают в счётчик раздела")
    func sectionCountsLearnedWords() async throws {
        let (catalog, context) = try await makeCatalog()
        let repository = WordRepository(context: context)

        // Отмечаем выученной одну фразу.
        let phrase = try #require(try repository.allWords().first(where: \.isPhrase))
        let progress = repository.progress(for: phrase)
        progress.stateRaw = CardState.review.rawValue
        progress.intervalDays = 30
        try repository.save()

        try catalog.load()
        let phrases = try #require(catalog.sections.first { $0.kind == .phrases })
        #expect(phrases.learned == 1)
        #expect(abs(phrases.share - 1.0 / 168.0) < 0.0001)
    }
}
