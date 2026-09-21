//
//  DataImporter.swift
//  CzechVocab / Data / Import
//
//  Импорт словаря из бандла в SwiftData на фоновом контексте.
//
//  Ключевое свойство: импорт идемпотентен и безопасен для прогресса.
//  Существующие `Word` обновляются по `id`, связанный `WordProgress` не трогается —
//  поэтому данные можно перевыкладывать (примеры ещё не вычитаны носителем, ТЗ 16.5),
//  не сбрасывая пользователю выученное.
//

import Foundation
import OSLog
import SwiftData

@ModelActor
actor DataImporter {

    /// Итог импорта. Числа сверяются тестом с разделом 3.4 ТЗ.
    nonisolated struct Summary: Sendable, Equatable {
        var imported = 0
        var updated = 0
        var skipped = 0
        var duration: TimeInterval = 0

        var total: Int { imported + updated }
    }

    enum ImportError: Error {
        case resourceNotFound(String)
        case unreadableResource(String)
    }

    private static let logger = Logger(subsystem: "com.CzechLearning", category: "import")

    /// Сколько записей пишется между сохранениями контекста: компромисс между
    /// расходом памяти и числом обращений к хранилищу.
    private static let saveBatchSize = 250

    // MARK: - Запуск

    /// Импортирует словарь из файла бандла.
    /// - Parameter progress: вызывается с долей 0…1 по мере обработки строк.
    func importVocabulary(
        from url: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) throws -> Summary {
        let started = Date()

        guard let data = try? Data(contentsOf: url) else {
            throw ImportError.unreadableResource(url.lastPathComponent)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError.unreadableResource(url.lastPathComponent)
        }

        let parser = CSVParser()
        let parsed = try parser.parseRows(text, requiredColumns: WordRecord.requiredColumns)

        for lineNumber in parsed.skippedRows {
            Self.logger.warning("Строка \(lineNumber): неверное число полей, пропущена")
        }

        var summary = Summary(skipped: parsed.skippedRows.count)

        // Один проход по существующим словам вместо выборки на каждую строку.
        var existing: [Int: Word] = [:]
        let stored = try modelContext.fetch(FetchDescriptor<Word>())
        existing.reserveCapacity(stored.count)
        for word in stored {
            existing[word.id] = word
        }

        let totalRows = parsed.rows.count
        var processedSinceSave = 0

        for (index, row) in parsed.rows.enumerated() {
            switch WordRecord.make(from: row) {
            case .failure(let failure):
                summary.skipped += 1
                Self.logger.warning(
                    "Строка \(row.lineNumber): \(String(describing: failure)), пропущена"
                )
            case .success(let record):
                if let word = existing[record.id] {
                    apply(record, to: word)
                    summary.updated += 1
                } else {
                    let word = makeWord(from: record)
                    modelContext.insert(word)
                    existing[record.id] = word
                    summary.imported += 1
                }
                processedSinceSave += 1
            }

            if processedSinceSave >= Self.saveBatchSize {
                try modelContext.save()
                processedSinceSave = 0
            }
            if totalRows > 0 {
                progress?(Double(index + 1) / Double(totalRows))
            }
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }

        summary.duration = Date().timeIntervalSince(started)
        Self.logger.info(
            """
            Импорт завершён: новых \(summary.imported), обновлено \(summary.updated), \
            пропущено \(summary.skipped), за \(summary.duration, format: .fixed(precision: 2)) с
            """
        )
        return summary
    }

    // MARK: - Запись

    private func makeWord(from record: WordRecord) -> Word {
        Word(
            id: record.id,
            czech: record.czech,
            partOfSpeechRaw: record.partOfSpeech.rawValue,
            grammarTagRaw: record.grammarTag?.rawValue,
            genitive: record.genitive,
            levelRaw: record.level.rawValue,
            category: record.category,
            russian: record.russian,
            ukrainian: record.ukrainian,
            english: record.english,
            note: record.note,
            imageURLString: record.imageURLString,
            example1CS: record.example1CS,
            example1RU: record.example1RU,
            example1UK: record.example1UK,
            example2CS: record.example2CS,
            example2RU: record.example2RU,
            example2UK: record.example2UK,
            searchKey: record.searchKey
        )
    }

    /// Обновляет поля существующей записи. `progress` намеренно не упоминается.
    private func apply(_ record: WordRecord, to word: Word) {
        word.czech = record.czech
        word.partOfSpeechRaw = record.partOfSpeech.rawValue
        word.grammarTagRaw = record.grammarTag?.rawValue
        word.genitive = record.genitive
        word.levelRaw = record.level.rawValue
        word.category = record.category
        word.russian = record.russian
        word.ukrainian = record.ukrainian
        word.english = record.english
        word.note = record.note
        word.imageURLString = record.imageURLString
        word.example1CS = record.example1CS
        word.example1RU = record.example1RU
        word.example1UK = record.example1UK
        word.example2CS = record.example2CS
        word.example2RU = record.example2RU
        word.example2UK = record.example2UK
        word.searchKey = record.searchKey
    }
}

// MARK: - Ресурс словаря

nonisolated enum VocabularyResource {

    static let fileName = "czech_vocabulary_A1_B1_full_en"
    static let fileExtension = "csv"

    /// Версия данных. Если она больше сохранённой в `UserDefaults`, запускается переимпорт.
    ///
    /// 2 — мужской род размечен одушевлённостью (`м.р. одуш.` / `м.р. неодуш.`).
    /// Установленным приложениям нужен переимпорт: у них в базе лежит старое
    /// значение пометки. Для прогресса это безопасно (ТЗ 5.2).
    static let dataVersion = 2

    /// URL CSV в бандле приложения. В юнит-тестах хостом выступает само приложение,
    /// поэтому `Bundle.main` указывает на его бандл и здесь, и в тестах.
    static func url(in bundle: Bundle = .main) throws -> URL {
        guard let url = bundle.url(forResource: fileName, withExtension: fileExtension) else {
            throw DataImporter.ImportError.resourceNotFound("\(fileName).\(fileExtension)")
        }
        return url
    }
}
