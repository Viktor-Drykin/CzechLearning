//
//  DataImporterTests.swift
//  CzechLearningTests
//
//  Числа сверяются с разделом 3.4 ТЗ и подтверждены прогоном по реальному CSV.
//

import Foundation
import SwiftData
import Testing

@testable import CzechLearning

@Suite("Импорт словаря")
struct DataImporterTests {

    // Ожидаемая статистика из ТЗ 3.4.
    private enum Expected {
        static let total = 1744
        static let words = 1576
        static let phrases = 168
        static let a1 = 694
        static let a2 = 559
        static let b1 = 491
        static let categories = 57
        static let withGenitive = 856
        static let withImageURL = 1005
        static let withNote = 38
        static let examples = 3488
        // Разбивка существительных по роду (ТЗ 3.4).
        static let masculineAnimate = 78
        static let masculineInanimate = 268
        static let feminine = 343
        static let neuter = 132
        static let pluralOnly = 35
    }

    // MARK: - Инструменты

    private func makeContainer() throws -> ModelContainer {
        try AppSchema.makeInMemoryContainer()
    }

    private func runImport(into container: ModelContainer) async throws -> DataImporter.Summary {
        let url = try VocabularyResource.url()
        let importer = DataImporter(modelContainer: container)
        return try await importer.importVocabulary(from: url)
    }

    @MainActor
    private func allWords(in container: ModelContainer) throws -> [Word] {
        try ModelContext(container).fetch(FetchDescriptor<Word>())
    }

    // MARK: - Числа раздела 3.4

    @Test("Импортируются все 1744 записи с ожидаемой разбивкой")
    @MainActor
    func importsExpectedStatistics() async throws {
        let container = try makeContainer()
        let summary = try await runImport(into: container)

        #expect(summary.imported == Expected.total)
        #expect(summary.updated == 0)
        #expect(summary.skipped == 0)

        let words = try allWords(in: container)
        #expect(words.count == Expected.total)

        #expect(words.filter { !$0.isPhrase }.count == Expected.words)
        #expect(words.filter(\.isPhrase).count == Expected.phrases)

        #expect(words.filter { $0.level == .a1 }.count == Expected.a1)
        #expect(words.filter { $0.level == .a2 }.count == Expected.a2)
        #expect(words.filter { $0.level == .b1 }.count == Expected.b1)

        #expect(Set(words.map(\.category)).count == Expected.categories)
        #expect(words.filter { $0.genitiveForm != nil }.count == Expected.withGenitive)
        #expect(words.filter { $0.imageURL != nil }.count == Expected.withImageURL)
        #expect(words.filter { $0.noteText != nil }.count == Expected.withNote)

        let byTag = { (tag: GrammarTag) in words.filter { $0.grammarTag == tag }.count }
        #expect(byTag(.masculineAnimate) == Expected.masculineAnimate)
        #expect(byTag(.masculineInanimate) == Expected.masculineInanimate)
        #expect(byTag(.feminine) == Expected.feminine)
        #expect(byTag(.neuter) == Expected.neuter)
        #expect(byTag(.plural) == Expected.pluralOnly)

        let exampleCount = words.reduce(into: 0) { total, word in
            total += word.examples(for: .russian).filter { !$0.czech.isEmpty }.count
        }
        #expect(exampleCount == Expected.examples)
    }

    @Test("Идентификаторы покрывают диапазон 1…1744 без пропусков")
    @MainActor
    func identifiersAreContiguous() async throws {
        let container = try makeContainer()
        _ = try await runImport(into: container)

        let ids = try allWords(in: container).map(\.id).sorted()
        #expect(ids.first == 1)
        #expect(ids.last == Expected.total)
        #expect(ids == Array(1...Expected.total))
    }

    @Test("Все картинки ведут только на loremflickr.com")
    @MainActor
    func imagesComeFromSingleHost() async throws {
        let container = try makeContainer()
        _ = try await runImport(into: container)

        let hosts = try allWords(in: container).compactMap { $0.imageURL?.host() }
        #expect(Set(hosts) == ["loremflickr.com"])
    }

    @Test("searchKey строится без диакритики и в нижнем регистре")
    @MainActor
    func buildsSearchKey() async throws {
        let container = try makeContainer()
        _ = try await runImport(into: container)

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.czech == "pozor" })
        descriptor.fetchLimit = 1
        let pozor = try #require(try context.fetch(descriptor).first)

        #expect(pozor.searchKey == "pozor")
        #expect(pozor.russian.contains("внимание"))
        #expect(pozor.ukrainian.contains("увага"))

        let all = try allWords(in: container)
        #expect(all.allSatisfy { $0.searchKey == TextNormalization.foldDiacritics($0.czech) })
        #expect(all.contains { $0.czech != $0.searchKey })
    }

    // MARK: - Идемпотентность

    @Test("Повторный импорт не создаёт дубликатов и не трогает прогресс")
    @MainActor
    func reimportIsIdempotentAndKeepsProgress() async throws {
        let container = try makeContainer()
        _ = try await runImport(into: container)

        // Пользователь «выучил» одно слово.
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.id == 443 })
        descriptor.fetchLimit = 1
        let word = try #require(try context.fetch(descriptor).first)

        let progress = WordProgress(
            word: word,
            stateRaw: CardState.review.rawValue,
            easeFactor: 2.36,
            intervalDays: 30,
            dueDate: .now.addingTimeInterval(SRSConstants.secondsPerDay * 30),
            repetitions: 5,
            lapses: 1,
            totalReviews: 7,
            correctReviews: 6
        )
        context.insert(progress)
        try context.save()

        let second = try await runImport(into: container)
        #expect(second.imported == 0)
        #expect(second.updated == Expected.total)
        #expect(second.skipped == 0)

        let words = try allWords(in: container)
        #expect(words.count == Expected.total)

        let verifyContext = ModelContext(container)
        var verifyDescriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.id == 443 })
        verifyDescriptor.fetchLimit = 1
        let reloaded = try #require(try verifyContext.fetch(verifyDescriptor).first)
        let keptProgress = try #require(reloaded.progress)

        #expect(keptProgress.state == .review)
        #expect(keptProgress.intervalDays == 30)
        #expect(keptProgress.repetitions == 5)
        #expect(keptProgress.correctReviews == 6)

        let allProgress = try verifyContext.fetch(FetchDescriptor<WordProgress>())
        #expect(allProgress.count == 1, "Импорт не должен создавать WordProgress")
    }

    @Test("Импорт 1744 строк укладывается в 3 секунды")
    @MainActor
    func importIsFastEnough() async throws {
        let container = try makeContainer()
        let summary = try await runImport(into: container)
        #expect(summary.duration < 3.0, "Импорт занял \(summary.duration) с")
    }

    // MARK: - Валидация строк

    @Test("Невалидная строка пропускается, остальные импортируются")
    func skipsInvalidRows() throws {
        let header = WordRecord.requiredColumns.joined(separator: ",")
        let valid = "1,konec,сущ.,A1,Базовые слова,конец,кінець,Film.,Фильм.,Фільм.,Na konci.,В конце.,В кінці."
        let badLevel = "2,pozor,сущ.,C2,Базовые слова,внимание,увага,A.,Б.,В.,Г.,Д.,Е."
        let badPOS = "3,slovo,глагольчик,A1,Базовые слова,слово,слово,A.,Б.,В.,Г.,Д.,Е."
        let badID = "x,slovo,сущ.,A1,Базовые слова,слово,слово,A.,Б.,В.,Г.,Д.,Е."
        let emptyField = "4,,сущ.,A1,Базовые слова,слово,слово,A.,Б.,В.,Г.,Д.,Е."

        let text = ([header, valid, badLevel, badPOS, badID, emptyField]).joined(separator: "\r\n")
        let parsed = try CSVParser().parseRows(text, requiredColumns: WordRecord.requiredColumns)
        #expect(parsed.rows.count == 5)

        let results = parsed.rows.map(WordRecord.make(from:))
        #expect(results.filter { if case .success = $0 { true } else { false } }.count == 1)
        #expect(results[1] == .failure(.unknownLevel("C2")))
        #expect(results[2] == .failure(.unknownPartOfSpeech("глагольчик")))
        #expect(results[3] == .failure(.invalidID("x")))
        #expect(results[4] == .failure(.emptyRequiredField("czech")))
    }

    @Test("Части речи и пометки рода разбираются из русских сокращений")
    func parsesEnumerations() {
        #expect(PartOfSpeech(csvValue: "сущ.") == .noun)
        #expect(PartOfSpeech(csvValue: "фраза") == .phrase)
        #expect(PartOfSpeech(csvValue: "межд.") == .interjection)
        #expect(PartOfSpeech(csvValue: "") == nil)

        #expect(GrammarTag(csvValue: "м.р. одуш.") == .masculineAnimate)
        #expect(GrammarTag(csvValue: "м.р. неодуш.") == .masculineInanimate)
        #expect(GrammarTag(csvValue: "мн.ч.") == .plural)
        // Мужской род без одушевлённости — ошибка данных, а не пометка.
        #expect(GrammarTag(csvValue: "м.р.") == nil)
        #expect(GrammarTag.isIncompleteMasculine(csvValue: "м.р."))
        #expect(GrammarTag(csvValue: "несов.") == .imperfective)
        #expect(GrammarTag(csvValue: "") == nil)
    }

    @Test("Все 11 частей речи и 6 пометок встречаются в данных как ожидается")
    @MainActor
    func csvUsesOnlyKnownEnumerations() async throws {
        let container = try makeContainer()
        _ = try await runImport(into: container)
        let words = try allWords(in: container)

        let usedTags = Set(words.compactMap(\.grammarTag))
        #expect(usedTags == Set(GrammarTag.allCases))

        let usedPOS = Set(words.map(\.partOfSpeech))
        #expect(usedPOS == Set(PartOfSpeech.allCases))
    }

    // MARK: - Вычисляемые свойства Word

    @Test("primaryTranslation берёт первое значение до точки с запятой")
    @MainActor
    func primaryTranslation() async throws {
        let container = try makeContainer()
        _ = try await runImport(into: container)

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.czech == "pozor" })
        descriptor.fetchLimit = 1
        let pozor = try #require(try context.fetch(descriptor).first)

        #expect(pozor.russian == "внимание; осторожно")
        #expect(pozor.primaryTranslation(for: .russian) == "внимание")
        #expect(pozor.translationMeanings(for: .russian) == ["внимание", "осторожно"])
        #expect(pozor.examples(for: .russian).count == 2)
    }
}
