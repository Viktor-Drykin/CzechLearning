//
//  TextNormalization.swift
//  CzechVocab / Domain
//
//  Нормализация чешского текста: снятие диакритики для поиска,
//  cloze-матчинга и сверки ответа в письменном вводе.
//

import Foundation

nonisolated enum TextNormalization {

    /// Ключ поиска: NFD-нормализация → выбросить комбинирующие знаки (категория `Mn`)
    /// → lowercase. `Přítel` → `pritel`, `ČERSTVÝ` → `cerstvy`.
    ///
    /// Именно это значение лежит в `Word.searchKey` и сравнивается при поиске
    /// по каталогу и при проверке ответа без диакритики.
    static func foldDiacritics(_ string: String) -> String {
        strippingDiacritics(string).lowercased()
    }

    /// Строка без диакритики, без приведения регистра — нужна там, где регистр важен.
    static func strippingDiacritics(_ string: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in string.decomposedStringWithCanonicalMapping.unicodeScalars
        where !isCombiningMark(scalar) {
            result.append(scalar)
        }
        return String(result)
    }

    /// Первое слово строки. Для `dívat se` — `dívat`, для фразы — первое слово фразы.
    static func firstWord(of string: String) -> String {
        string
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)
            ?? ""
    }

    /// Расстояние Левенштейна. Используется в проверке ответа (ТЗ 7.3, п. 4),
    /// где порог — 1, поэтому полная матрица не нужна: хватает двух строк.
    static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        var previous = Array(0...right.count)
        var current = [Int](repeating: 0, count: right.count + 1)

        for i in 1...left.count {
            current[0] = i
            for j in 1...right.count {
                let substitution = previous[j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }

    /// Комбинирующий диакритический знак: всё, что после NFD осталось «навесным».
    private static func isCombiningMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: true
        default: false
        }
    }
}
