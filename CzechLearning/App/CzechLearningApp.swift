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
    private let storage: AppSchema.Storage

    init() {
        (container, storage) = AppSchema.openContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView(storage: storage)
                .dynamicTypeSize(...AppTypography.maximumSize)
        }
        .modelContainer(container)
    }
}
