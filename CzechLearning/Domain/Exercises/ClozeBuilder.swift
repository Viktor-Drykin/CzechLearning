//
//  ClozeBuilder.swift
//  CzechVocab / Domain / Exercises
//
//  Пропуск в примере (ТЗ 7.6). Чешский — флективный язык, поэтому слово
//  в примере стоит в другой форме, чем в словаре: ищем по основе, а не целиком.
//
//  Покрытие на текущих данных — 1676 из 1744 записей (96 %).
//

import Foundation

nonisolated enum ClozeBuilder {

    struct Cloze: Sendable, Equatable {
        /// Предложение с заменой целевого слова на пропуск.
        let sentence: String
        /// Форма, которая была заменена, — её показываем при проверке.
        let answer: String
        /// Из какого примера взято: 0 или 1.
        let exampleIndex: Int
    }

    static let blank = "_____"

    /// Минимальная и максимальная длина основы поиска (ТЗ 7.6, п. 2).
    private static let minimumStem = 3
    private static let maximumStem = 5

    /// Строит пропуск по первому примеру, где нашлось слово; иначе `nil`
    /// — тогда показывается обычная обратная сторона.
    static func build(for word: Word) -> Cloze? {
        build(czech: word.czech, examples: [word.example1CS, word.example2CS])
    }

    static func build(czech: String, examples: [String]) -> Cloze? {
        guard let stem = stem(for: czech) else { return nil }

        for (index, example) in examples.enumerated() {
            guard let range = matchRange(of: stem, in: example) else { continue }
            let answer = String(example[range])
            let sentence = example.replacingCharacters(in: range, with: blank)
            return Cloze(sentence: sentence, answer: answer, exampleIndex: index)
        }
        return nil
    }

    /// Есть ли пропуск для слова — для подсчёта покрытия в тесте.
    static func hasCloze(czech: String, examples: [String]) -> Bool {
        build(czech: czech, examples: examples) != nil
    }

    // MARK: - Основа

    /// Основа: первые `min(5, max(3, длина − 1))` символов нормализованного
    /// первого слова. Короткие слова (предлоги, союзы) основы не дают.
    static func stem(for czech: String) -> String? {
        let normalized = TextNormalization.foldDiacritics(TextNormalization.firstWord(of: czech))
        guard normalized.count >= minimumStem else { return nil }

        let length = min(maximumStem, max(minimumStem, normalized.count - 1))
        return String(normalized.prefix(length))
    }

    // MARK: - Поиск

    /// Ищет в примере слово, начинающееся с основы, и возвращает диапазон
    /// найденной словоформы в исходной строке — с диакритикой и регистром.
    ///
    /// Сопоставление идёт по нормализованному тексту, но индексы считаются
    /// по словам исходной строки: снятие диакритики не меняет число символов,
    /// зато меняет их, поэтому подменять строку целиком нельзя.
    private static func matchRange(of stem: String, in example: String) -> Range<String.Index>? {
        var index = example.startIndex

        while index < example.endIndex {
            // Начало слова: либо начало строки, либо после разделителя.
            let isWordStart = index == example.startIndex
                || !example[example.index(before: index)].isLetter

            guard isWordStart, example[index].isLetter else {
                index = example.index(after: index)
                continue
            }

            var end = index
            while end < example.endIndex, example[end].isLetter {
                end = example.index(after: end)
            }

            let candidate = example[index..<end]
            if TextNormalization.foldDiacritics(String(candidate)).hasPrefix(stem) {
                return index..<end
            }
            index = end
        }
        return nil
    }
}
