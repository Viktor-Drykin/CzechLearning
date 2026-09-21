//
//  ClozeBuilder.swift
//  CzechVocab / Domain / Exercises
//
//  Пропуск в примере (ТЗ 7.6). Чешский — флективный язык, поэтому слово
//  в примере стоит в другой форме, чем в словаре: ищем по основе, а не целиком.
//
//  Покрытие на текущих данных — 1672 из 1744 записей (95,9 %), порог ТЗ — 95 %.
//  Непокрытые — слова, у которых в примере меняется корень: основа «kone»
//  от «konec» не совпадает с формой «konce».
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

    /// Границы длины основы поиска (ТЗ 7.6, п. 2).
    private static let minimumStem = 3
    private static let maximumStem = 5

    /// Слова не длиннее этого ищутся точным совпадением, а не по основе.
    ///
    /// У «na», «den», «a» основа равна самому слову, и поиск по префиксу
    /// поймал бы «nashledanou» или «denně» — пропуск встал бы не на то слово.
    private static let exactMatchMaximumLength = 3

    /// Строит пропуск по первому примеру, где нашлось слово; иначе `nil`
    /// — тогда показывается обычная обратная сторона.
    static func build(for word: Word) -> Cloze? {
        build(czech: word.czech, examples: [word.example1CS, word.example2CS])
    }

    static func build(czech: String, examples: [String]) -> Cloze? {
        guard let stem = stem(for: czech) else { return nil }
        let normalizedWord = TextNormalization.foldDiacritics(TextNormalization.firstWord(of: czech))
        let requiresExactMatch = normalizedWord.count <= exactMatchMaximumLength

        for (index, example) in examples.enumerated() {
            guard let range = matchRange(
                of: requiresExactMatch ? normalizedWord : stem,
                in: example,
                exact: requiresExactMatch
            ) else { continue }
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
    /// первого слова. У слов короче трёх символов основа равна самому слову.
    static func stem(for czech: String) -> String? {
        let normalized = TextNormalization.foldDiacritics(TextNormalization.firstWord(of: czech))
        guard !normalized.isEmpty else { return nil }

        let length = min(maximumStem, max(minimumStem, normalized.count - 1))
        return String(normalized.prefix(length))
    }

    // MARK: - Поиск

    /// Ищет в примере слово, начинающееся с основы (или равное ей при `exact`),
    /// и возвращает диапазон найденной словоформы в исходной строке —
    /// с диакритикой и регистром.
    ///
    /// Сопоставление идёт по нормализованному слову, но индексы считаются
    /// по исходной строке: на неё и накладывается пропуск.
    private static func matchRange(
        of stem: String,
        in example: String,
        exact: Bool
    ) -> Range<String.Index>? {
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

            let candidate = TextNormalization.foldDiacritics(String(example[index..<end]))
            let matches = exact ? candidate == stem : candidate.hasPrefix(stem)
            if matches {
                return index..<end
            }
            index = end
        }
        return nil
    }
}
