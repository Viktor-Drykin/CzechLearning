//
//  StatsTests.swift
//  CzechLearningTests
//
//  Сводка прогресса и влияние настроек на очередь следующей сессии.
//

import Foundation
import SwiftData
import Testing

@testable import CzechLearning

@Suite("Прогресс")
@MainActor
struct StatsTests {

    // MARK: - Инструменты

    private func makeContainer(wordCount: Int = 9) throws -> ModelContainer {
        let container = try AppSchema.makeInMemoryContainer()
        let context = ModelContext(container)
        let levels: [CEFRLevel] = [.a1, .a2, .b1]
        let categories = ["Еда", "Транспорт", "Работа"]

        for id in 1...wordCount {
            context.insert(
                Word(
                    id: id,
                    czech: "slovo\(id)",
                    partOfSpeechRaw: PartOfSpeech.noun.rawValue,
                    grammarTagRaw: nil,
                    genitive: nil,
                    levelRaw: levels[(id - 1) % levels.count].rawValue,
                    category: categories[(id - 1) % categories.count],
                    russian: "слово\(id)",
                    ukrainian: "слово\(id)",
                    english: nil,
                    note: nil,
                    imageURLString: nil,
                    example1CS: "Toto je slovo\(id).",
                    example1RU: "Это слово\(id).",
                    example1UK: "Це слово\(id).",
                    example2CS: "Slovo\(id) je zde.",
                    example2RU: "Слово\(id) здесь.",
                    example2UK: "Слово\(id) тут.",
                    searchKey: "slovo\(id)"
                )
            )
        }
        try context.save()
        return container
    }

    private func makeStats(_ context: ModelContext) -> StatsViewModel {
        StatsViewModel(
            repository: WordRepository(context: context),
            statsRepository: StatsRepository(context: context)
        )
    }

    // MARK: - Плитки

    @Test("Пустая база: всё в «новых», выученных нет")
    func emptyState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let stats = makeStats(context)

        try stats.refresh()
        #expect(stats.learnedCount == 0)
        #expect(stats.inProgressCount == 0)
        #expect(stats.remainingNewCount == 9)
        #expect(stats.averageAccuracy == 0)
    }

    @Test("Слова делятся на выученные, в изучении и новые")
    func countsByState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = WordRepository(context: context)

        // Выученное: review и интервал от 21 дня.
        let learned = try #require(try repository.word(id: 1))
        let learnedProgress = repository.progress(for: learned)
        learnedProgress.stateRaw = CardState.review.rawValue
        learnedProgress.intervalDays = 30
        learnedProgress.totalReviews = 10
        learnedProgress.correctReviews = 9

        // В изучении: review, но интервал меньше порога.
        let started = try #require(try repository.word(id: 2))
        let startedProgress = repository.progress(for: started)
        startedProgress.stateRaw = CardState.review.rawValue
        startedProgress.intervalDays = 5
        startedProgress.totalReviews = 10
        startedProgress.correctReviews = 5
        try repository.save()

        let stats = makeStats(context)
        try stats.refresh()

        #expect(stats.learnedCount == 1)
        #expect(stats.inProgressCount == 1)
        #expect(stats.remainingNewCount == 7)
        #expect(abs(stats.averageAccuracy - 0.7) < 0.0001, "14 верных из 20")
    }

    @Test("Порог «выучено» — ровно 21 день")
    func learnedThresholdIsExact() throws {
        let container = try makeContainer(wordCount: 2)
        let context = ModelContext(container)
        let repository = WordRepository(context: context)

        for (id, interval) in [(1, 21.0), (2, 20.99)] {
            let word = try #require(try repository.word(id: id))
            let progress = repository.progress(for: word)
            progress.stateRaw = CardState.review.rawValue
            progress.intervalDays = interval
        }
        try repository.save()

        let stats = makeStats(context)
        try stats.refresh()
        #expect(stats.learnedCount == 1)
        #expect(stats.inProgressCount == 1)
    }

    // MARK: - Разбивка

    @Test("Разбивка по уровням покрывает все три уровня")
    func levelBreakdown() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let stats = makeStats(context)

        try stats.refresh()
        #expect(stats.levels.map(\.title) == ["A1", "A2", "B1"])
        #expect(stats.levels.allSatisfy { $0.total == 3 })
        #expect(stats.levels.allSatisfy { $0.share == 0 })
    }

    @Test("Темы сортируются по проценту освоения")
    func categoriesSortedByShare() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = WordRepository(context: context)

        // Два слова из «Транспорта» (id 2 и 5) становятся выученными.
        for id in [2, 5] {
            let word = try #require(try repository.word(id: id))
            let progress = repository.progress(for: word)
            progress.stateRaw = CardState.review.rawValue
            progress.intervalDays = 30
        }
        try repository.save()

        let stats = makeStats(context)
        try stats.refresh()

        #expect(stats.categories.first?.title == "Транспорт")
        #expect(stats.categories.first?.learned == 2)
        let shares = stats.categories.map(\.share)
        #expect(shares == shares.sorted(by: >), "Сортировка по убыванию доли")
    }

    // MARK: - График

    @Test("График отдаёт ровно 30 дней, включая дни без ответов")
    func activityCoversThirtyDays() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let stats = makeStats(context)

        try stats.refresh()
        #expect(stats.activity.count == StatsViewModel.activityDays)
        #expect(stats.activityMaximum == 0)

        // Дни идут по возрастанию и не повторяются.
        let days = stats.activity.map(\.day)
        #expect(days == days.sorted())
        #expect(Set(days).count == days.count)
    }

    @Test("Ответы сессии попадают в сегодняшний столбец графика")
    func todayAppearsInChart() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let statsRepository = StatsRepository(context: context)

        try statsRepository.recordAnswer(wasNew: true, correct: true)
        try statsRepository.recordAnswer(wasNew: false, correct: false)
        try context.save()

        let stats = makeStats(context)
        try stats.refresh()

        let today = try #require(stats.activity.last)
        #expect(today.day == DailyStats.dayKey(for: .now))
        #expect(today.answers == 2)
        #expect(stats.activityMaximum == 2)
    }

    // MARK: - Настройки влияют на сессию

    @Test("Изменённый лимит новых сразу действует на следующую сессию")
    func newLimitAppliesImmediately() throws {
        let container = try makeContainer(wordCount: 30)
        let context = ModelContext(container)
        let suite = UserDefaults(suiteName: "stats.\(UUID().uuidString)") ?? .standard
        let settings = SettingsStore(defaults: suite)

        settings.newCardsPerDay = 5
        let first = StudySessionViewModel(
            mode: .flashcards,
            deck: .all,
            repository: WordRepository(context: context),
            statsRepository: StatsRepository(context: context),
            settings: settings
        )
        try first.loadQueue()
        #expect(first.queue.count == 5)

        // Меняем настройку — новая сессия обязана её увидеть.
        settings.newCardsPerDay = 20
        let second = StudySessionViewModel(
            mode: .flashcards,
            deck: .all,
            repository: WordRepository(context: context),
            statsRepository: StatsRepository(context: context),
            settings: settings
        )
        try second.loadQueue()
        #expect(second.queue.count == 20)
    }

    @Test("Сброс прогресса действительно всё очищает")
    func resetClearsProgressAndStats() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = WordRepository(context: context)
        let statsRepository = StatsRepository(context: context)

        let word = try #require(try repository.word(id: 1))
        try repository.recordAnswer(word: word, grade: .good, mode: .flashcards, responseTime: 2)
        try statsRepository.recordAnswer(wasNew: true, correct: true)
        try repository.save()

        let before = makeStats(context)
        try before.refresh()
        #expect(before.remainingNewCount == 8)

        try statsRepository.resetAllProgress()

        let after = makeStats(context)
        try after.refresh()
        #expect(after.learnedCount == 0)
        #expect(after.inProgressCount == 0)
        #expect(after.remainingNewCount == 9, "Все слова снова новые")
        #expect(after.activityMaximum == 0)
        #expect(try context.fetch(FetchDescriptor<Word>()).count == 9, "Словарь остался")
    }

    @Test("Смена языка перевода меняет подсказки без перезагрузки словаря")
    func translationLanguageSwitches() throws {
        let container = try makeContainer(wordCount: 1)
        let context = ModelContext(container)
        let word = try #require(try WordRepository(context: context).word(id: 1))

        #expect(word.translation(for: .russian) == "слово1")
        #expect(word.translation(for: .ukrainian) == "слово1")
        #expect(word.examples(for: .russian).first?.translated == "Это слово1.")
        #expect(word.examples(for: .ukrainian).first?.translated == "Це слово1.")
    }
}
