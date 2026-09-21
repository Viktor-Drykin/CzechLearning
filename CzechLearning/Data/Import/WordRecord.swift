//
//  WordRecord.swift
//  CzechVocab / Data / Import
//
//  Value-снимок строки CSV: результат валидации, вход для записи в SwiftData.
//  Отдельный тип нужен, чтобы валидацию можно было тестировать без контейнера.
//

import Foundation

nonisolated struct WordRecord: Sendable, Equatable {

    let id: Int
    let czech: String
    let partOfSpeech: PartOfSpeech
    let grammarTag: GrammarTag?
    let genitive: String?
    let level: CEFRLevel
    let category: String
    let russian: String
    let ukrainian: String
    let english: String?
    let note: String?
    let imageURLString: String?
    let example1CS: String
    let example1RU: String
    let example1UK: String
    let example2CS: String
    let example2RU: String
    let example2UK: String
    let searchKey: String
}

nonisolated extension WordRecord {

    /// Колонки, без которых файл считается неподходящим.
    static let requiredColumns = [
        "id", "czech", "part_of_speech", "level", "category",
        "russian", "ukrainian",
        "example_1_cs", "example_1_ru", "example_1_uk",
        "example_2_cs", "example_2_ru", "example_2_uk",
    ]

    /// Причина, по которой строка не прошла валидацию. Строка пропускается,
    /// импорт продолжается (ТЗ 5.2, п. 3).
    enum ValidationFailure: Error, Equatable {
        case invalidID(String)
        case unknownPartOfSpeech(String)
        case unknownLevel(String)
        case emptyRequiredField(String)
        /// Мужской род без пометки одушевлённости (ТЗ 3.3): пропустить такую
        /// строку честнее, чем потерять пометку и покрасить слово наугад.
        case incompleteMasculine(String)
    }

    /// Разбор и валидация одной строки CSV.
    static func make(from row: CSVParser.Row) -> Result<WordRecord, ValidationFailure> {
        guard let idText = row.required("id"), let id = Int(idText) else {
            return .failure(.invalidID(row["id"]))
        }
        guard let posText = row.required("part_of_speech"),
              let partOfSpeech = PartOfSpeech(csvValue: posText)
        else {
            return .failure(.unknownPartOfSpeech(row["part_of_speech"]))
        }
        guard let levelText = row.required("level"),
              let level = CEFRLevel(rawValue: levelText)
        else {
            return .failure(.unknownLevel(row["level"]))
        }

        let genderAspect = row["gender_aspect"]
        guard !GrammarTag.isIncompleteMasculine(csvValue: genderAspect) else {
            return .failure(.incompleteMasculine(genderAspect))
        }

        // Непустые по ТЗ: слово, оба перевода, оба примера со своими переводами.
        let mandatory = [
            "czech", "category", "russian", "ukrainian",
            "example_1_cs", "example_1_ru", "example_1_uk",
            "example_2_cs", "example_2_ru", "example_2_uk",
        ]
        var resolved: [String: String] = [:]
        for column in mandatory {
            guard let value = row.required(column) else {
                return .failure(.emptyRequiredField(column))
            }
            resolved[column] = value
        }

        let czech = resolved["czech", default: ""]

        return .success(
            WordRecord(
                id: id,
                czech: czech,
                partOfSpeech: partOfSpeech,
                grammarTag: row.optional("gender_aspect").flatMap(GrammarTag.init(csvValue:)),
                genitive: row.optional("genitive"),
                level: level,
                category: resolved["category", default: ""],
                russian: resolved["russian", default: ""],
                ukrainian: resolved["ukrainian", default: ""],
                english: row.optional("english"),
                note: row.optional("note"),
                imageURLString: row.optional("image_url"),
                example1CS: resolved["example_1_cs", default: ""],
                example1RU: resolved["example_1_ru", default: ""],
                example1UK: resolved["example_1_uk", default: ""],
                example2CS: resolved["example_2_cs", default: ""],
                example2RU: resolved["example_2_ru", default: ""],
                example2UK: resolved["example_2_uk", default: ""],
                searchKey: TextNormalization.foldDiacritics(czech)
            )
        )
    }
}
