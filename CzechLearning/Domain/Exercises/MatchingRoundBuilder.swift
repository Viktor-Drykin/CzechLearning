//
//  MatchingRoundBuilder.swift
//  CzechVocab / Domain / Exercises
//
//  Раунд режима «Пары»: 5 чешских слов слева, их переводы вперемешку справа
//  (ТЗ 7.5). Набор берётся из головы очереди.
//

import Foundation

nonisolated struct MatchingRoundBuilder {

    /// Сколько пар в раунде.
    static let pairCount = 5

    struct Tile: Sendable, Equatable, Identifiable {
        enum Side: Sendable, Equatable {
            case czech
            case translation
        }

        /// Идентификатор плитки на экране.
        let id: String
        /// Слово, которому принадлежит плитка.
        let wordID: Int
        let side: Side
        let text: String
        /// Заполнен только у чешской стороны: перевод по роду не красим.
        var nounGender: NounGender?
    }

    struct Round: Sendable, Equatable {
        let wordIDs: [Int]
        let czechTiles: [Tile]
        let translationTiles: [Tile]

        var isEmpty: Bool { wordIDs.isEmpty }
    }

    /// Строит раунд из головы очереди. Переводы перемешиваются независимо,
    /// иначе пары стояли бы напротив друг друга.
    static func build(
        from candidates: [MatchingWord],
        language: TranslationLanguage,
        shuffle: ([Tile]) -> [Tile] = { $0.shuffled() }
    ) -> Round {
        let selected = Array(candidates.prefix(pairCount))
        guard !selected.isEmpty else {
            return Round(wordIDs: [], czechTiles: [], translationTiles: [])
        }

        let czech = selected.map {
            Tile(
                id: "cz-\($0.id)",
                wordID: $0.id,
                side: .czech,
                text: $0.czech,
                nounGender: $0.nounGender
            )
        }
        let translations = selected.map {
            Tile(
                id: "tr-\($0.id)",
                wordID: $0.id,
                side: .translation,
                text: $0.primaryTranslation(for: language)
            )
        }

        return Round(
            wordIDs: selected.map(\.id),
            czechTiles: shuffle(czech),
            translationTiles: shuffle(translations)
        )
    }

    /// Верная ли пара.
    static func isMatch(_ first: Tile, _ second: Tile) -> Bool {
        first.side != second.side && first.wordID == second.wordID
    }
}

// MARK: - Вход

/// Минимум, нужный режиму «Пары» от слова.
nonisolated struct MatchingWord: Sendable, Equatable, Identifiable {

    let id: Int
    let czech: String
    let russian: String
    let ukrainian: String
    /// Род существительного — чешская плитка красится по нему.
    var nounGender: NounGender?

    func primaryTranslation(for language: TranslationLanguage) -> String {
        switch language {
        case .russian: russian
        case .ukrainian: ukrainian
        }
    }
}

extension MatchingWord {

    init(word: Word) {
        self.init(
            id: word.id,
            czech: word.czech,
            russian: word.primaryTranslation(for: .russian),
            ukrainian: word.primaryTranslation(for: .ukrainian),
            nounGender: word.nounGender
        )
    }
}
