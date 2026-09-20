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

    /// Контейнер в памяти — для тестов и превью.
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }
}
