//
//  CzechLearningApp.swift
//  CzechVocab / App
//

import SwiftData
import SwiftUI

@main
struct CzechLearningApp: App {

    /// Контейнер создаётся один раз на запуск: его пересоздание обнулило бы
    /// открытые контексты и наблюдение во вьюхах.
    private let container: ModelContainer

    init() {
        do {
            container = try AppSchema.makeContainer()
        } catch {
            // Хранилище не открылось — работать не с чем; падение здесь честнее,
            // чем тихая работа с пустой базой в памяти.
            fatalError("Не удалось открыть хранилище SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .dynamicTypeSize(...AppTypography.maximumSize)
        }
        .modelContainer(container)
    }
}
