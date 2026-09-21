//
//  ExerciseTests.swift
//  CzechLearningTests
//
//  Дистракторы, проверка ответа, cloze и раунд «Пар».
//

import Foundation
import SwiftData
import Testing

@testable import CzechLearning

// MARK: - Дистракторы

@Suite("Генератор дистракторов")
struct DistractorGeneratorTests {

    /// Детерминированное «перемешивание» — иначе правила приоритета не проверить.
    private let keepOrder: ([DistractorCandidate]) -> [DistractorCandidate] = { $0 }

    private func candidate(
        _ id: Int,
        _ czech: String,
        russian: [String],
        level: CEFRLevel = .a1,
        category: String = "Еда",
        isPhrase: Bool = false,
        note: String? = nil
    ) -> DistractorCandidate {
        DistractorCandidate(
            id: id,
            czech: czech,
            level: level,
            category: category,
            isPhrase: isPhrase,
            russianMeanings: russian,
            ukrainianMeanings: russian.map { $0 + "_uk" },
            note: note
        )
    }

    // MARK: Правила приоритета

    @Test("Сначала берутся слова той же темы и того же уровня")
    func prefersSameCategoryAndLevel() {
        let target = candidate(1, "chleba", russian: ["хлеб"])
        let dictionary = [
            target,
            candidate(2, "maso", russian: ["мясо"]),
            candidate(3, "sýr", russian: ["сыр"]),
            candidate(4, "mléko", russian: ["молоко"]),
            candidate(5, "auto", russian: ["машина"], category: "Транспорт"),
            candidate(6, "vlak", russian: ["поезд"], level: .b1, category: "Транспорт"),
        ]

        let result = DistractorGenerator.distractors(
            for: target,
            in: dictionary,
            language: .russian,
            shuffle: keepOrder
        )
        #expect(result.map(\.id) == [2, 3, 4])
    }

    @Test("Когда своей темы мало, добираются слова того же уровня")
    func fallsBackToSameLevel() {
        let target = candidate(1, "chleba", russian: ["хлеб"])
        let dictionary = [
            target,
            candidate(2, "maso", russian: ["мясо"]),
            candidate(3, "auto", russian: ["машина"], category: "Транспорт"),
            candidate(4, "dům", russian: ["дом"], category: "Дом"),
        ]

        let result = DistractorGenerator.distractors(
            for: target,
            in: dictionary,
            language: .russian,
            shuffle: keepOrder
        )
        #expect(result.count == 3)
        #expect(result.first?.id == 2, "Слово своей темы идёт первым")
    }

    @Test("Всегда набирается ровно три дистрактора, если словарь позволяет")
    func alwaysReturnsThree() {
        let target = candidate(1, "chleba", russian: ["хлеб"])
        let dictionary = [target] + (2...20).map {
            candidate($0, "slovo\($0)", russian: ["слово\($0)"], level: .b1, category: "Разное")
        }

        let result = DistractorGenerator.distractors(
            for: target,
            in: dictionary,
            language: .russian,
            shuffle: keepOrder
        )
        #expect(result.count == DistractorGenerator.distractorCount)
    }

    // MARK: Ограничения

    @Test("Целевое слово в дистракторы не попадает")
    func excludesTarget() {
        let target = candidate(1, "chleba", russian: ["хлеб"])
        let dictionary = [target, candidate(2, "maso", russian: ["мясо"])]

        let result = DistractorGenerator.distractors(
            for: target,
            in: dictionary,
            language: .russian,
            shuffle: keepOrder
        )
        #expect(!result.contains { $0.id == target.id })
    }

    @Test("Варианты не повторяются по переводу")
    func rejectsDuplicateTranslations() {
        let target = candidate(1, "auto", russian: ["машина"])
        let dictionary = [
            target,
            candidate(2, "vůz", russian: ["машина"]),
            candidate(3, "stroj", russian: ["машина"]),
            candidate(4, "kolo", russian: ["велосипед"]),
            candidate(5, "vlak", russian: ["поезд"]),
        ]

        let result = DistractorGenerator.distractors(
            for: target,
            in: dictionary,
            language: .russian,
            shuffle: keepOrder
        )
        #expect(!result.contains { $0.primaryTranslation(for: .russian) == "машина" })
        #expect(Set(result.map { $0.primaryTranslation(for: .russian) }).count == result.count)
    }

    @Test("К обычному слову фразы в варианты не предлагаются")
    func excludesPhrasesForWords() {
        let target = candidate(1, "chleba", russian: ["хлеб"])
        let dictionary = [
            target,
            candidate(2, "Dobrý den", russian: ["добрый день"], isPhrase: true),
            candidate(3, "maso", russian: ["мясо"]),
            candidate(4, "sýr", russian: ["сыр"]),
            candidate(5, "mléko", russian: ["молоко"]),
        ]

        let result = DistractorGenerator.distractors(
            for: target,
            in: dictionary,
            language: .russian,
            shuffle: keepOrder
        )
        #expect(!result.contains { $0.isPhrase })
    }

    @Test("Вариантов на экране всегда четыре, и верный среди них ровно один")
    func optionsContainExactlyOneCorrect() {
        let target = candidate(1, "chleba", russian: ["хлеб"])
        let dictionary = [target] + (2...10).map {
            candidate($0, "slovo\($0)", russian: ["слово\($0)"])
        }

        let options = DistractorGenerator.options(
            for: target,
            in: dictionary,
            language: .russian,
            shuffle: keepOrder
        )
        #expect(options.count == DistractorGenerator.optionCount)
        #expect(options.filter { $0.id == target.id }.count == 1)
    }

    // MARK: Ложные друзья

    @Test("Из примечания берётся слово в кавычках, а не «друг» из самого маркера")
    func falseFriendIgnoresMarkerWord() {
        let target = candidate(
            1, "čas",
            russian: ["время"],
            note: "Ложный друг: «час» = hodina"
        )
        let dictionary = [
            target,
            candidate(2, "kamarád", russian: ["друг"]),
            candidate(3, "hodina", russian: ["час"]),
            candidate(4, "den", russian: ["день"]),
            candidate(5, "rok", russian: ["год"]),
        ]

        let confusable = DistractorGenerator.falseFriendDistractor(
            for: target,
            in: dictionary,
            language: .russian
        )
        #expect(confusable?.czech == "hodina", "Слово «друг» из маркера не должно совпадать")

        let result = DistractorGenerator.distractors(
            for: target,
            in: dictionary,
            language: .russian,
            shuffle: keepOrder
        )
        #expect(result.first?.czech == "hodina", "Спутываемое слово идёт первым вариантом")
    }

    @Test("Без совпадения в словаре правило ложных друзей пропускается")
    func falseFriendRuleIsOptional() {
        let target = candidate(
            1, "pozor",
            russian: ["внимание", "осторожно"],
            note: "Ложный друг: НЕ «позор»"
        )
        let dictionary = [
            target,
            candidate(2, "maso", russian: ["мясо"]),
            candidate(3, "sýr", russian: ["сыр"]),
            candidate(4, "mléko", russian: ["молоко"]),
        ]

        #expect(
            DistractorGenerator.falseFriendDistractor(
                for: target,
                in: dictionary,
                language: .russian
            ) == nil
        )
        // Варианты всё равно набираются.
        let result = DistractorGenerator.distractors(
            for: target,
            in: dictionary,
            language: .russian,
            shuffle: keepOrder
        )
        #expect(result.count == 3)
    }

    @Test("Примечание без маркера правило не включает")
    func plainNoteDoesNotTriggerRule() {
        let target = candidate(1, "hospoda", russian: ["пивная"], note: "Ключевое место чешской культуры")
        let dictionary = [target, candidate(2, "kultura", russian: ["культура"])]

        #expect(
            DistractorGenerator.falseFriendDistractor(
                for: target,
                in: dictionary,
                language: .russian
            ) == nil
        )
    }

    @Test(
        "Фрагменты в кавычках-ёлочках разбираются",
        arguments: [
            ("Ложный друг: «час» = hodina", ["час"]),
            ("Ложный друг: НЕ «позор»", ["позор"]),
            ("Ложный друг: «родина» по-чешски vlast", ["родина"]),
            ("Без кавычек", []),
        ]
    )
    func parsesQuotedFragments(note: String, expected: [String]) {
        #expect(DistractorGenerator.quotedFragments(in: note) == expected)
    }

}

// MARK: - Дистракторы на реальных данных

/// Отдельным набором: тесты поднимают контейнер SwiftData и потому живут
/// на главном акторе, в отличие от чистых проверок правил выше.
@Suite("Дистракторы на реальном словаре")
@MainActor
struct DistractorGeneratorRealDataTests {

    @Test("Правило ложных друзей срабатывает ровно на четырёх записях")
    func falseFriendsOnRealData() async throws {
        let container = try AppSchema.makeInMemoryContainer()
        _ = try await DataImporter(modelContainer: container)
            .importVocabulary(from: VocabularyResource.url())

        let context = ModelContext(container)
        let words = try context.fetch(FetchDescriptor<Word>())
        let dictionary = words.map(DistractorCandidate.init(word:))

        let marked = dictionary.filter {
            $0.note?.contains(DistractorGenerator.falseFriendMarker) == true
        }
        #expect(marked.count == 7, "«Ложный друг» встречается в семи примечаниях")

        var resolved: [String: String] = [:]
        for target in marked {
            if let confusable = DistractorGenerator.falseFriendDistractor(
                for: target,
                in: dictionary,
                language: .russian
            ) {
                resolved[target.czech] = confusable.czech
            }
        }

        // Для трёх записей спутываемого слова в словаре нет (позор, чёрствый,
        // бригада) — правило корректно пропускается.
        #expect(resolved == [
            "čas": "hodina",
            "neděle": "týden",
            "ovoce": "zelenina",
            "rodina": "vlast",
        ])
    }

    @Test("У каждого слова набирается четыре варианта")
    func fullOptionsOnRealData() async throws {
        let container = try AppSchema.makeInMemoryContainer()
        _ = try await DataImporter(modelContainer: container)
            .importVocabulary(from: VocabularyResource.url())

        let context = ModelContext(container)
        let dictionary = try context.fetch(FetchDescriptor<Word>()).map(DistractorCandidate.init(word:))

        // Проверяем выборку: полный прогон по 1744 словам занял бы минуты.
        for target in stride(from: 0, to: dictionary.count, by: 37).map({ dictionary[$0] }) {
            let options = DistractorGenerator.options(
                for: target,
                in: dictionary,
                language: .russian
            )
            #expect(options.count == 4, "Слово \(target.czech)")
            #expect(options.filter { $0.id == target.id }.count == 1)
        }
    }
}

// MARK: - Проверка ответа

@Suite("Проверка письменного ответа")
struct AnswerValidatorTests {

    @Test("Точное совпадение — верно")
    func exactMatch() {
        #expect(AnswerValidator.validate(answer: "přítel", expected: "přítel") == .correct)
        #expect(AnswerValidator.validate(answer: "  PŘÍTEL  ", expected: "přítel") == .correct)
    }

    @Test("Совпадение без диакритики — верно, но с предупреждением")
    func missingDiacritics() {
        #expect(
            AnswerValidator.validate(answer: "pritel", expected: "přítel") == .correctWithoutDiacritics
        )
        #expect(
            AnswerValidator.validate(answer: "cerstvy", expected: "čerstvý") == .correctWithoutDiacritics
        )
    }

    @Test("Опечатка в одну букву при длине от пяти символов — «почти верно»")
    func singleTypo() {
        #expect(AnswerValidator.validate(answer: "prited", expected: "přítel") == .almostCorrect)
        #expect(AnswerValidator.validate(answer: "pritl", expected: "přítel") == .almostCorrect)
        #expect(AnswerValidator.validate(answer: "priteel", expected: "přítel") == .almostCorrect)
    }

    @Test("У коротких слов опечатка не прощается: это уже другое слово")
    func shortWordsAreStrict() {
        #expect(AnswerValidator.validate(answer: "ne", expected: "no") == .incorrect)
        #expect(AnswerValidator.validate(answer: "dan", expected: "den") == .incorrect)
    }

    @Test("Две ошибки — неверно")
    func twoErrorsAreIncorrect() {
        // «pritl» → расстояние 1, а «pritk» → 2: вторая замена уже не прощается.
        #expect(AnswerValidator.validate(answer: "pritkk", expected: "přítel") == .incorrect)
        #expect(AnswerValidator.validate(answer: "", expected: "přítel") == .incorrect)
    }

    @Test("Совсем другое слово — неверно")
    func differentWord() {
        #expect(AnswerValidator.validate(answer: "kamarád", expected: "přítel") == .incorrect)
    }

    // MARK: Потолок оценки

    @Test("Точный ответ оценивается по времени без потолка")
    func exactAnswerUsesTime() {
        #expect(AnswerValidator.grade(for: .correct, responseTime: 1) == .easy)
        #expect(AnswerValidator.grade(for: .correct, responseTime: 5) == .good)
        #expect(AnswerValidator.grade(for: .correct, responseTime: 20) == .hard)
    }

    @Test("Ответ без диакритики не поднимается выше «Трудно», как бы быстро ни был дан")
    func diacriticsCeiling() {
        #expect(AnswerValidator.grade(for: .correctWithoutDiacritics, responseTime: 0.5) == .hard)
        #expect(AnswerValidator.grade(for: .correctWithoutDiacritics, responseTime: 5) == .hard)
        #expect(AnswerValidator.grade(for: .correctWithoutDiacritics, responseTime: 30) == .hard)
    }

    @Test("«Почти верно» тоже ограничено «Трудно»")
    func typoCeiling() {
        #expect(AnswerValidator.grade(for: .almostCorrect, responseTime: 0.5) == .hard)
        #expect(AnswerValidator.grade(for: .almostCorrect, responseTime: 30) == .hard)
    }

    @Test("Неверный ответ и «Не знаю» — это «Снова»")
    func failureIsAgain() {
        #expect(AnswerValidator.grade(for: .incorrect, responseTime: 1) == .again)
        #expect(AnswerValidator.grade(for: .gaveUp, responseTime: 1) == .again)
        #expect(AnswerValidator.Outcome.gaveUp.isAccepted == false)
    }

    // MARK: Подсветка

    @Test("Диакритические знаки помечаются для подсветки")
    func highlightsDiacritics() {
        let parts = AnswerValidator.highlightDiacritics(in: "přítel")
        #expect(parts.count == 6)
        #expect(parts.map(\.isDiacritic) == [false, true, true, false, false, false])
    }

    @Test("Слово без диакритики подсвечивать нечего")
    func nothingToHighlight() {
        let parts = AnswerValidator.highlightDiacritics(in: "konec")
        #expect(parts.allSatisfy { !$0.isDiacritic })
    }
}

// MARK: - Cloze

@Suite("Пропуск в предложении")
struct ClozeBuilderTests {

    @Test("Слово в примере заменяется на пропуск")
    func buildsCloze() throws {
        let cloze = try #require(
            ClozeBuilder.build(czech: "kniha", examples: ["Kniha leží na stole.", "Čtu knihu."])
        )
        #expect(cloze.sentence == "_____ leží na stole.")
        #expect(cloze.answer == "Kniha")
        #expect(cloze.exampleIndex == 0)
    }

    @Test("Основа короче словоформы: «konec» не находится в «konce»")
    func stemMayMissInflection() {
        // Основа «kone» не совпадает с «konce»: в чешском корень меняется,
        // и такие слова остаются без cloze — это те 4 %, что не покрыты.
        #expect(ClozeBuilder.stem(for: "konec") == "kone")
        #expect(ClozeBuilder.build(czech: "konec", examples: ["Film je u konce."]) == nil)
    }

    @Test("Словоформа находится по основе, а не по точному совпадению")
    func matchesInflectedForm() throws {
        let cloze = try #require(
            ClozeBuilder.build(czech: "přítel", examples: ["Mám dobrého přítele."])
        )
        #expect(cloze.sentence == "Mám dobrého _____.")
        #expect(cloze.answer == "přítele")
    }

    @Test("Если в первом примере слова нет, берётся второй")
    func fallsBackToSecondExample() throws {
        let cloze = try #require(
            ClozeBuilder.build(czech: "kniha", examples: ["Tady to je.", "Čtu knihu."])
        )
        #expect(cloze.exampleIndex == 1)
        #expect(cloze.sentence == "Čtu _____.")
    }

    @Test("Если слова нет нигде, cloze недоступен")
    func returnsNilWhenNotFound() {
        #expect(ClozeBuilder.build(czech: "kniha", examples: ["Tady to je.", "Nic tu není."]) == nil)
    }

    @Test("Короткие слова ищутся точным совпадением, а не по префиксу")
    func shortWordsMatchExactly() {
        // «na» не должно поймать «nashledanou», зато находит само себя.
        #expect(ClozeBuilder.build(czech: "na", examples: ["Na shledanou."]) != nil)
        #expect(ClozeBuilder.build(czech: "na", examples: ["Nashledanou zítra."]) == nil)
        #expect(ClozeBuilder.build(czech: "den", examples: ["Denně chodím pěšky."]) == nil)
    }

    @Test("У пустой строки основы нет")
    func emptyWordHasNoStem() {
        #expect(ClozeBuilder.stem(for: "") == nil)
        #expect(ClozeBuilder.stem(for: "   ") == nil)
    }

    @Test(
        "Основа — первые min(5, max(3, длина − 1)) символов",
        arguments: [
            ("a", "a"),
            ("na", "na"),
            ("den", "den"),
            ("kniha", "knih"),
            ("přítel", "prite"),
            ("nemocnice", "nemoc"),
            ("dívat se", "diva"),
        ]
    )
    func stemLength(czech: String, expected: String) {
        #expect(ClozeBuilder.stem(for: czech) == expected)
    }

    @Test("Основа ищется по границе слова, а не внутри другого")
    func matchesOnWordBoundary() {
        // «den» не должно совпасть с «vedení» в середине слова.
        #expect(ClozeBuilder.build(czech: "den", examples: ["Vedení firmy."]) == nil)
        #expect(ClozeBuilder.build(czech: "den", examples: ["Dnes je hezký den."]) != nil)
    }

    @Test("Покрытие на реальных данных не ниже 95 %")
    func coverageOnRealData() throws {
        let text = try String(contentsOf: try VocabularyResource.url(), encoding: .utf8)
        let parsed = try CSVParser().parseRows(text, requiredColumns: WordRecord.requiredColumns)

        let covered = parsed.rows.count { row in
            ClozeBuilder.hasCloze(
                czech: row["czech"],
                examples: [row["example_1_cs"], row["example_2_cs"]]
            )
        }
        let share = Double(covered) / Double(parsed.rows.count)

        #expect(parsed.rows.count == 1744)
        #expect(covered == 1672, "Покрытие на текущих данных — 1672 записи")
        #expect(share >= 0.95, "Покрытие \(share) ниже порога 95 % из ТЗ 7.6")
    }
}

// MARK: - Пары

@Suite("Режим «Пары»")
struct MatchingRoundBuilderTests {

    private func words(_ count: Int) -> [MatchingWord] {
        (1...count).map {
            MatchingWord(id: $0, czech: "slovo\($0)", russian: "слово\($0)", ukrainian: "слово\($0)_uk")
        }
    }

    @Test("Раунд берёт пять слов из головы очереди")
    func takesFivePairs() {
        let round = MatchingRoundBuilder.build(from: words(12), language: .russian) { $0 }
        #expect(round.wordIDs == [1, 2, 3, 4, 5])
        #expect(round.czechTiles.count == 5)
        #expect(round.translationTiles.count == 5)
    }

    @Test("Хвост очереди короче пяти — раунд короче")
    func handlesShortTail() {
        let round = MatchingRoundBuilder.build(from: words(3), language: .russian) { $0 }
        #expect(round.wordIDs.count == 3)
    }

    @Test("Пустая очередь даёт пустой раунд")
    func handlesEmptyQueue() {
        let round = MatchingRoundBuilder.build(from: [], language: .russian) { $0 }
        #expect(round.isEmpty)
    }

    @Test("Плитки разных колонок с одним словом образуют пару")
    func detectsMatch() {
        let round = MatchingRoundBuilder.build(from: words(5), language: .russian) { $0 }
        let czech = round.czechTiles[0]
        let correct = try? #require(round.translationTiles.first { $0.wordID == czech.wordID })
        let wrong = round.translationTiles.first { $0.wordID != czech.wordID }

        #expect(MatchingRoundBuilder.isMatch(czech, correct ?? czech))
        #expect(MatchingRoundBuilder.isMatch(czech, wrong ?? czech) == false)
        // Две плитки одной колонки парой не считаются.
        #expect(MatchingRoundBuilder.isMatch(czech, round.czechTiles[0]) == false)
    }

    @Test("Перевод берётся по выбранному языку")
    func usesSelectedLanguage() {
        let ru = MatchingRoundBuilder.build(from: words(1), language: .russian) { $0 }
        let uk = MatchingRoundBuilder.build(from: words(1), language: .ukrainian) { $0 }
        #expect(ru.translationTiles.first?.text == "слово1")
        #expect(uk.translationTiles.first?.text == "слово1_uk")
    }
}
