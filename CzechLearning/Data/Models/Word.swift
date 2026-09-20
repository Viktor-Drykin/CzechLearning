//
//  Word.swift
//  CzechVocab / Data / Models
//
//  Словарная запись. Поля хранятся «сырыми» (как в CSV), типизированный доступ —
//  через вычисляемые свойства в extension: SwiftData не умеет хранить enum
//  с кастомным разбором, а переимпорт должен уметь класть значение как есть.
//

import Foundation
import SwiftData

@Model
final class Word {

    @Attribute(.unique) var id: Int
    var czech: String
    var partOfSpeechRaw: String
    var grammarTagRaw: String?
    var genitive: String?
    var levelRaw: String
    var category: String
    var russian: String
    var ukrainian: String
    var english: String?
    var note: String?
    var imageURLString: String?
    var example1CS: String
    var example1RU: String
    var example1UK: String
    var example2CS: String
    var example2RU: String
    var example2UK: String

    /// Нормализованное поле для поиска: `czech` без диакритики, lowercase.
    /// Заполняется при импорте, используется для поиска и для cloze-матчинга.
    var searchKey: String

    @Relationship(deleteRule: .cascade, inverse: \WordProgress.word)
    var progress: WordProgress?

    init(
        id: Int,
        czech: String,
        partOfSpeechRaw: String,
        grammarTagRaw: String?,
        genitive: String?,
        levelRaw: String,
        category: String,
        russian: String,
        ukrainian: String,
        english: String?,
        note: String?,
        imageURLString: String?,
        example1CS: String,
        example1RU: String,
        example1UK: String,
        example2CS: String,
        example2RU: String,
        example2UK: String,
        searchKey: String
    ) {
        self.id = id
        self.czech = czech
        self.partOfSpeechRaw = partOfSpeechRaw
        self.grammarTagRaw = grammarTagRaw
        self.genitive = genitive
        self.levelRaw = levelRaw
        self.category = category
        self.russian = russian
        self.ukrainian = ukrainian
        self.english = english
        self.note = note
        self.imageURLString = imageURLString
        self.example1CS = example1CS
        self.example1RU = example1RU
        self.example1UK = example1UK
        self.example2CS = example2CS
        self.example2RU = example2RU
        self.example2UK = example2UK
        self.searchKey = searchKey
    }
}

// MARK: - Типизированный доступ

nonisolated extension Word {

    /// Часть речи. Невалидные значения отсеивает импортёр, поэтому в базе
    /// остаются только разбираемые — но запас на `.phrase` держим без падения.
    var partOfSpeech: PartOfSpeech {
        PartOfSpeech(rawValue: partOfSpeechRaw) ?? .phrase
    }

    var grammarTag: GrammarTag? {
        grammarTagRaw.flatMap(GrammarTag.init(rawValue:))
    }

    var level: CEFRLevel {
        CEFRLevel(rawValue: levelRaw) ?? .a1
    }

    var isPhrase: Bool {
        partOfSpeech == .phrase
    }

    var imageURL: URL? {
        guard let imageURLString, !imageURLString.isEmpty else { return nil }
        return URL(string: imageURLString)
    }

    /// Родительный падеж — только у существительных и только если он есть в данных.
    var genitiveForm: String? {
        guard let genitive, !genitive.isEmpty else { return nil }
        return genitive
    }

    /// Примечание, если оно непустое.
    var noteText: String? {
        guard let note, !note.isEmpty else { return nil }
        return note
    }

    func translation(for language: TranslationLanguage) -> String {
        switch language {
        case .russian: russian
        case .ukrainian: ukrainian
        }
    }

    /// Первое значение до `;` — для вариантов ответа и компактных списков,
    /// где полная строка «сторона; страница» не помещается.
    func primaryTranslation(for language: TranslationLanguage) -> String {
        let full = translation(for: language)
        guard let separator = full.firstIndex(of: ";") else { return full }
        return String(full[full.startIndex..<separator])
            .trimmingCharacters(in: .whitespaces)
    }

    /// Все значения перевода, разделённые `;`.
    func translationMeanings(for language: TranslationLanguage) -> [String] {
        translation(for: language)
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Ровно две пары «чешский пример — перевод».
    func examples(for language: TranslationLanguage) -> [(czech: String, translated: String)] {
        switch language {
        case .russian:
            [(example1CS, example1RU), (example2CS, example2RU)]
        case .ukrainian:
            [(example1CS, example1UK), (example2CS, example2UK)]
        }
    }
}
