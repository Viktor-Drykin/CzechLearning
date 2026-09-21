//
//  StudySessionTests.swift
//  CzechLearningTests
//
//  Полный цикл сессии на контейнере в памяти: ответы записываются,
//  провалы возвращаются внутри сессии, прогресс переживает пересоздание контекста.
//

import Foundation
import SwiftData
import Testing

@testable import CzechLearning

@Suite("Сессия обучения")
@MainActor
struct StudySessionTests {

    // MARK: - Инструменты

    /// Словарь из нескольких слов вместо полного CSV: сессию проверяем,
    /// а не импорт — он покрыт своими тестами.
    private func makeContainer(wordCount: Int = 12) throws -> ModelContainer {
        let container = try AppSchema.makeInMemoryContainer()
        let context = ModelContext(container)

        for id in 1...wordCount {
            context.insert(
                Word(
                    id: id,
                    czech: "slovo\(id)",
                    partOfSpeechRaw: PartOfSpeech.noun.rawValue,
                    grammarTagRaw: GrammarTag.masculine.rawValue,
                    genitive: "slova\(id)",
                    levelRaw: CEFRLevel.a1.rawValue,
                    category: "Еда",
                    russian: "слово\(id)",
                    ukrainian: "слово\(id)",
                    english: "word\(id)",
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

    private func makeSession(
        container: ModelContainer,
        context: ModelContext,
        settings: SettingsStore
    ) -> StudySessionViewModel {
        StudySessionViewModel(
            mode: .flashcards,
            deck: .all,
            repository: WordRepository(context: context),
            statsRepository: StatsRepository(context: context),
            settings: settings
        )
    }

    private func makeSettings(newPerDay: Int = 10) -> SettingsStore {
        let suite = UserDefaults(suiteName: "tests.\(UUID().uuidString)") ?? .standard
        let settings = SettingsStore(defaults: suite)
        settings.newCardsPerDay = newPerDay
        return settings
    }

    // MARK: - Очередь

    @Test("Сессия берёт ровно столько новых слов, сколько разрешает лимит")
    func respectsDailyNewLimit() throws {
        let container = try makeContainer(wordCount: 30)
        let context = ModelContext(container)
        let session = makeSession(container: container, context: context, settings: makeSettings(newPerDay: 10))

        try session.loadQueue()
        #expect(session.queue.count == 10)
        #expect(session.initialNewCount == 10)
        #expect(session.remainingCount == 10)
    }

    @Test("Второй заход за день не выдаёт новые сверх дневного лимита")
    func newLimitIsDaily() throws {
        let container = try makeContainer(wordCount: 30)
        let context = ModelContext(container)
        let settings = makeSettings(newPerDay: 5)

        let first = makeSession(container: container, context: context, settings: settings)
        try first.loadQueue()
        for _ in 0..<5 {
            first.submit(grade: .easy)
        }
        #expect(first.isFinished)

        let second = makeSession(container: container, context: context, settings: settings)
        try second.loadQueue()
        #expect(second.queue.isEmpty, "Лимит новых на сегодня уже выбран")

        // «Учить вперёд» выдаёт лимит заново.
        let ahead = makeSession(container: container, context: context, settings: settings)
        try ahead.loadQueue(aheadOfSchedule: true)
        #expect(ahead.queue.count == 5)
    }

    // MARK: - Полный цикл

    @Test("Сессия из 10 карточек проходится до итогов")
    func completesFullSession() throws {
        let container = try makeContainer(wordCount: 10)
        let context = ModelContext(container)
        let session = makeSession(container: container, context: context, settings: makeSettings())

        try session.loadQueue()
        #expect(session.queue.count == 10)

        // `easy` уводит карточку в review — внутри сессии она не повторяется.
        while !session.isFinished {
            session.submit(grade: .easy)
        }

        #expect(session.summary.answered == 10)
        #expect(session.summary.correct == 10)
        #expect(session.summary.newLearned == 10)
        #expect(abs(session.summary.accuracy - 1.0) < 0.0001)
        #expect(session.progressValue >= 1.0)
    }

    @Test("Карточка, отвеченная «Снова», возвращается внутри той же сессии")
    func againRepeatsWithinSession() throws {
        let container = try makeContainer(wordCount: 3)
        let context = ModelContext(container)
        let session = makeSession(container: container, context: context, settings: makeSettings())

        try session.loadQueue()
        let firstID = try #require(session.currentWord?.id)

        session.submit(grade: .again)
        #expect(session.queue.count == 4, "Карточка должна вернуться в конец очереди")
        #expect(session.queue.last?.id == firstID)

        // Остальные — сразу в review, чтобы дойти до возвращённой.
        session.submit(grade: .easy)
        session.submit(grade: .easy)
        #expect(session.currentWord?.id == firstID)
        #expect(session.isFinished == false)

        session.submit(grade: .easy)
        #expect(session.isFinished)
        #expect(session.summary.answered == 4)
        #expect(session.summary.correct == 3)
    }

    @Test("Прогресс-бар считает от исходного размера очереди, а не от текущего")
    func progressCountsFromPlannedSize() throws {
        let container = try makeContainer(wordCount: 4)
        let context = ModelContext(container)
        let session = makeSession(container: container, context: context, settings: makeSettings())

        try session.loadQueue()
        #expect(session.plannedCount == 4)

        session.submit(grade: .again)
        #expect(session.queue.count == 5, "Карточка вернулась в очередь")
        #expect(session.plannedCount == 4, "Знаменатель прогресса не растёт")
        #expect(abs(session.progressValue - 0.25) < 0.0001)
    }

    @Test("Ответ «Хорошо» на новой карточке оставляет её в изучении внутри сессии")
    func goodKeepsNewCardInLearning() throws {
        let container = try makeContainer(wordCount: 2)
        let context = ModelContext(container)
        let session = makeSession(container: container, context: context, settings: makeSettings())

        try session.loadQueue()
        let firstID = try #require(session.currentWord?.id)

        // new + good → learning, шаг 1, срок через 10 минут: внутри сессии.
        session.submit(grade: .good)
        #expect(session.queue.count == 3)
        #expect(session.queue.last?.id == firstID)

        let progress = try #require(try WordRepository(context: context).word(id: firstID)?.progress)
        #expect(progress.state == .learning)
        #expect(progress.learningStepIndex == 1)
    }

    // MARK: - Сохранение

    @Test("Ответы сохраняются и переживают пересоздание контекста")
    func progressSurvivesContextRecreation() throws {
        let container = try makeContainer(wordCount: 3)
        let context = ModelContext(container)
        let session = makeSession(container: container, context: context, settings: makeSettings())

        // `easy` уводит карточку сразу в review, поэтому сессия не растягивается
        // внутрисессионными повторами — проверяем именно сохранение.
        try session.loadQueue()
        session.submit(grade: .easy)
        session.submit(grade: .easy)
        session.submit(grade: .easy)
        #expect(session.isFinished)

        // Новый контекст читает то же хранилище — как после перезапуска приложения.
        let fresh = ModelContext(container)
        let saved = try fresh.fetch(FetchDescriptor<WordProgress>())
        #expect(saved.count == 3)
        #expect(saved.allSatisfy { $0.totalReviews == 1 })

        let logs = try fresh.fetch(FetchDescriptor<ReviewLog>())
        #expect(logs.count == 3)
        #expect(logs.allSatisfy { $0.mode == .flashcards })

        let stats = try fresh.fetch(FetchDescriptor<DailyStats>())
        #expect(stats.count == 1)
        #expect(stats.first?.reviewsCompleted == 3)
        #expect(stats.first?.newCardsStudied == 3)
        #expect(stats.first?.correctCount == 3)
    }

    @Test("Неверный ответ уходит в статистику как непройденный")
    func wrongAnswerIsCountedSeparately() throws {
        let container = try makeContainer(wordCount: 2)
        let context = ModelContext(container)
        let session = makeSession(container: container, context: context, settings: makeSettings())

        try session.loadQueue()
        session.submit(grade: .again)
        session.submit(grade: .easy)

        let stats = try #require(try context.fetch(FetchDescriptor<DailyStats>()).first)
        #expect(stats.reviewsCompleted == 2)
        #expect(stats.correctCount == 1)
    }

    // MARK: - Подтверждение выхода

    @Test("Выход просит подтверждения, пока пройдено меньше половины")
    func closeConfirmationThreshold() throws {
        let container = try makeContainer(wordCount: 4)
        let context = ModelContext(container)
        let session = makeSession(container: container, context: context, settings: makeSettings())

        try session.loadQueue()
        #expect(session.needsCloseConfirmation)

        session.submit(grade: .easy)
        #expect(session.needsCloseConfirmation)

        session.submit(grade: .easy)
        #expect(session.needsCloseConfirmation == false)
    }

    // MARK: - Репозиторий

    @Test("Прогресс создаётся лениво, при первом показе карточки")
    func progressIsCreatedLazily() throws {
        let container = try makeContainer(wordCount: 3)
        let context = ModelContext(container)
        let repository = WordRepository(context: context)

        #expect(try repository.allProgress().isEmpty)

        let word = try #require(try repository.word(id: 1))
        repository.progress(for: word)
        try repository.save()

        #expect(try repository.allProgress().count == 1)

        // Повторный вызов не плодит записи.
        repository.progress(for: word)
        try repository.save()
        #expect(try repository.allProgress().count == 1)
    }

    @Test("Приостановленное слово не попадает в очередь")
    func suspendedWordIsExcluded() throws {
        let container = try makeContainer(wordCount: 3)
        let context = ModelContext(container)
        let repository = WordRepository(context: context)

        let word = try #require(try repository.word(id: 2))
        repository.setSuspended(true, for: word)
        try repository.save()

        let session = makeSession(container: container, context: context, settings: makeSettings())
        try session.loadQueue()
        #expect(session.queue.map(\.id) == [1, 3])
    }

    @Test("Сброс прогресса очищает состояния, журнал и дневную статистику")
    func resetClearsEverything() throws {
        let container = try makeContainer(wordCount: 3)
        let context = ModelContext(container)
        let session = makeSession(container: container, context: context, settings: makeSettings())

        try session.loadQueue()
        session.submit(grade: .good)
        session.submit(grade: .good)

        let stats = StatsRepository(context: context)
        try stats.resetAllProgress()

        #expect(try context.fetch(FetchDescriptor<WordProgress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ReviewLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DailyStats>()).isEmpty)
        // Словарь остаётся на месте.
        #expect(try context.fetch(FetchDescriptor<Word>()).count == 3)
    }

    // MARK: - Главный экран

    @Test("Главный экран показывает счётчики и прогресс колод")
    func homeSummary() throws {
        let container = try makeContainer(wordCount: 6)
        let context = ModelContext(container)
        let settings = makeSettings(newPerDay: 4)

        let home = HomeViewModel(
            repository: WordRepository(context: context),
            statsRepository: StatsRepository(context: context),
            settings: settings
        )
        try home.refresh()

        #expect(home.dueCount == 0)
        #expect(home.newCount == 4, "Новых не больше дневного лимита")
        #expect(home.hasUnseenWords)
        #expect(home.hasWorkToday)
        #expect(home.decks.count == 3)

        let a1 = try #require(home.decks.first { $0.level == .a1 })
        #expect(a1.total == 6)
        #expect(a1.learned == 0)
        #expect(a1.share == 0)
    }

    @Test("Выученным считается слово в review с интервалом от 21 дня")
    func learnedThreshold() throws {
        let container = try makeContainer(wordCount: 2)
        let context = ModelContext(container)
        let repository = WordRepository(context: context)

        let learned = try #require(try repository.word(id: 1))
        let progress = repository.progress(for: learned)
        progress.stateRaw = CardState.review.rawValue
        progress.intervalDays = 21

        let almost = try #require(try repository.word(id: 2))
        let other = repository.progress(for: almost)
        other.stateRaw = CardState.review.rawValue
        other.intervalDays = 20.9
        try repository.save()

        #expect(progress.isLearned)
        #expect(other.isLearned == false)
        #expect(other.isInProgress)
    }
}
