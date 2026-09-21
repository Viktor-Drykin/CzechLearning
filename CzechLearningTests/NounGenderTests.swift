//
//  NounGenderTests.swift
//  CzechLearningTests
//
//  Род существительного и цветовая подсказка по нему.
//

import Foundation
import SwiftData
import Testing

@testable import CzechLearning

@Suite("Род существительного")
@MainActor
struct NounGenderTests {

    // MARK: - Разбор пометки

    @Test(
        "Пометка из CSV разбирается в род",
        arguments: [
            ("ж.р.", NounGender.feminine),
            ("ср.р.", .neuter),
            ("м.р. одуш.", .masculineAnimate),
            ("м.р. неодуш.", .masculineInanimate),
        ]
    )
    func parsesGender(csv: String, expected: NounGender) {
        #expect(NounGender(csvValue: csv) == expected)
    }

    @Test("Мужской род без уточнения показывается как неодушевлённый")
    func incompleteMasculineFallsBackToInanimate() {
        // Правило «не знаешь, одушевлённый или нет, — значит синий».
        #expect(NounGender(csvValue: "м.р.") == .masculineInanimate)
        #expect(NounGender(csvValue: " м.р. ") == .masculineInanimate)
    }

    @Test(
        "У вида глагола и множественного числа рода нет",
        arguments: ["несов.", "сов.", "мн.ч.", "", "чепуха"]
    )
    func noGenderForOtherTags(csv: String) {
        #expect(NounGender(csvValue: csv) == nil)
    }

    @Test("Род выводится из грамматической пометки")
    func derivesFromGrammarTag() {
        #expect(NounGender(grammarTag: .masculineAnimate) == .masculineAnimate)
        #expect(NounGender(grammarTag: .masculineInanimate) == .masculineInanimate)
        #expect(NounGender(grammarTag: .feminine) == .feminine)
        #expect(NounGender(grammarTag: .neuter) == .neuter)
        #expect(NounGender(grammarTag: .plural) == nil)
        #expect(NounGender(grammarTag: .imperfective) == nil)
        #expect(NounGender(grammarTag: nil) == nil)
    }

    @Test("Каждому роду соответствует своя подпись")
    func everyGenderHasLabel() {
        let names = NounGender.allCases.map(\.displayName)
        #expect(names.count == 4)
        #expect(Set(names).count == 4, "Подписи не должны повторяться")
        #expect(names.allSatisfy { !$0.isEmpty })
    }

    // MARK: - На реальных данных

    private func makeContainer() async throws -> ModelContainer {
        let container = try AppSchema.makeInMemoryContainer()
        _ = try await DataImporter(modelContainer: container)
            .importVocabulary(from: VocabularyResource.url())
        return container
    }

    @Test("Все 856 существительных, кроме размеченных «мн.ч.», получают род")
    func everyNounHasGender() async throws {
        let container = try await makeContainer()
        let words = try ModelContext(container).fetch(FetchDescriptor<Word>())
        let nouns = words.filter { $0.partOfSpeech == .noun }

        #expect(nouns.count == 856)

        let plural = nouns.filter { $0.grammarTag == .plural }
        #expect(plural.count == 35)
        #expect(plural.allSatisfy { $0.nounGender == nil }, "У «мн.ч.» рода нет")

        let gendered = nouns.filter { $0.nounGender != nil }
        #expect(gendered.count == nouns.count - plural.count)

        var counts: [NounGender: Int] = [:]
        for noun in nouns {
            guard let gender = noun.nounGender else { continue }
            counts[gender, default: 0] += 1
        }
        #expect(counts[.masculineAnimate] == 78)
        #expect(counts[.masculineInanimate] == 268)
        #expect(counts[.feminine] == 343)
        #expect(counts[.neuter] == 132)
    }

    @Test("Не-существительные рода не получают, даже если пометка есть")
    func nonNounsHaveNoGender() async throws {
        let container = try await makeContainer()
        let words = try ModelContext(container).fetch(FetchDescriptor<Word>())

        let verbs = words.filter { $0.partOfSpeech == .verb }
        #expect(!verbs.isEmpty)
        #expect(verbs.allSatisfy { $0.nounGender == nil }, "У глаголов размечен вид, а не род")

        let others = words.filter { $0.partOfSpeech != .noun }
        #expect(others.allSatisfy { $0.nounGender == nil })
    }

    @Test(
        "Известные слова получают ожидаемый род",
        arguments: [
            ("pes", NounGender.masculineAnimate),
            ("učitel", .masculineAnimate),
            ("hrad", .masculineInanimate),
            ("konec", .masculineInanimate),
            ("žena", .feminine),
            ("rodina", .feminine),
            ("město", .neuter),
            ("auto", .neuter),
        ]
    )
    func knownWords(czech: String, expected: NounGender) async throws {
        let container = try await makeContainer()
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.czech == czech })
        descriptor.fetchLimit = 1

        let word = try #require(try context.fetch(descriptor).first, "Нет слова «\(czech)»")
        #expect(word.nounGender == expected)
    }

    // MARK: - Пометка на экране

    @Test("Подпись чипа у мужского рода всегда с одушевлённостью")
    func chipShowsAnimacy() {
        #expect(GrammarTag.masculineAnimate.displayName.contains("одуш."))
        #expect(GrammarTag.masculineInanimate.displayName.contains("неодуш."))
        // Цвет не единственный носитель смысла: пометка есть текстом.
        #expect(GrammarTag.feminine.displayName.isEmpty == false)
        #expect(GrammarTag.neuter.displayName.isEmpty == false)
    }

    @Test("Цветовую подсказку получают только роды, но не вид глагола")
    func onlyGendersAreTinted() {
        #expect(GrammarTag.masculineAnimate.chipTint != nil)
        #expect(GrammarTag.masculineInanimate.chipTint != nil)
        #expect(GrammarTag.feminine.chipTint != nil)
        #expect(GrammarTag.neuter.chipTint != nil)
        #expect(GrammarTag.plural.chipTint == nil)
        #expect(GrammarTag.imperfective.chipTint == nil)
        #expect(GrammarTag.perfective.chipTint == nil)
    }
}
