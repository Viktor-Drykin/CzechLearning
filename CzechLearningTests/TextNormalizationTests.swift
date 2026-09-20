//
//  TextNormalizationTests.swift
//  CzechLearningTests
//

import Foundation
import Testing

@testable import CzechLearning

@Suite("Нормализация текста")
struct TextNormalizationTests {

    @Test(
        "Диакритика снимается, регистр приводится к нижнему",
        arguments: [
            ("přítel", "pritel"),
            ("ČERSTVÝ", "cerstvy"),
            ("děkuji", "dekuji"),
            ("žluťoučký", "zlutoucky"),
            ("konec", "konec"),
            ("Na shledanou", "na shledanou"),
        ]
    )
    func foldsDiacritics(input: String, expected: String) {
        #expect(TextNormalization.foldDiacritics(input) == expected)
    }

    @Test("Регистр сохраняется, когда снимается только диакритика")
    func stripsWithoutLowercasing() {
        #expect(TextNormalization.strippingDiacritics("Příliš") == "Prilis")
    }

    @Test("Первое слово берётся до первого пробела")
    func firstWord() {
        #expect(TextNormalization.firstWord(of: "dívat se") == "dívat")
        #expect(TextNormalization.firstWord(of: "konec") == "konec")
        #expect(TextNormalization.firstWord(of: "") == "")
    }

    @Test(
        "Расстояние Левенштейна",
        arguments: [
            ("konec", "konec", 0),
            ("konec", "koned", 1),
            ("konec", "konc", 1),
            ("konec", "konecc", 1),
            ("konec", "kanac", 2),
            ("", "abc", 3),
        ]
    )
    func levenshtein(lhs: String, rhs: String, expected: Int) {
        #expect(TextNormalization.levenshteinDistance(lhs, rhs) == expected)
    }
}
