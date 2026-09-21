//
//  AppSchema.swift
//  CzechVocab / App
//
//  Единственное место, где перечислены модели. И приложение, и тесты
//  поднимают контейнер отсюда, поэтому схема не расходится.
//

import Foundation
import SwiftData

nonisolated enum AppSchema {

    static let models: [any PersistentModel.Type] = [
        Word.self,
        WordProgress.self,
        ReviewLog.self,
        DailyStats.self,
    ]

    static var schema: Schema {
        Schema(models)
    }

    /// Рабочий контейнер приложения: файл на диске, без CloudKit.
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        )
    }

    /// Чем открылось хранилище: важно для UI — при откате прогресс потерян.
    enum Storage {
        /// Обычное файловое хранилище.
        case onDisk
        /// Файл не открылся и был пересоздан: словарь переимпортируется,
        /// прогресс потерян.
        case recreated
        /// Не удалось и это — работаем в памяти, до перезапуска.
        case inMemory
    }

    /// Открывает хранилище, не роняя приложение.
    ///
    /// Файл базы восстановим: словарь переимпортируется из бандла, а терять
    /// прогресс лучше, чем падать при запуске на испорченном или несовместимом
    /// хранилище.
    static func openContainer() -> (container: ModelContainer, storage: Storage) {
        if let container = try? makeContainer() {
            return (container, .onDisk)
        }

        removeStoreFiles()
        if let container = try? makeContainer() {
            return (container, .recreated)
        }

        // Последний рубеж: приложение работает, но ничего не сохраняет.
        do {
            return (try makeInMemoryContainer(), .inMemory)
        } catch {
            // Схема не поднимается даже в памяти — это ошибка сборки, а не среды.
            preconditionFailure("Схема SwiftData не создаётся: \(error)")
        }
    }

    /// Удаляет файлы хранилища по умолчанию вместе с журналами WAL.
    private static func removeStoreFiles() {
        let manager = FileManager.default
        let store = URL.applicationSupportDirectory.appending(path: "default.store")
        for suffix in ["", "-shm", "-wal"] {
            let url = URL(filePath: store.path(percentEncoded: false) + suffix)
            try? manager.removeItem(at: url)
        }
    }

    /// Контейнер в памяти — для тестов и превью.
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }
}
