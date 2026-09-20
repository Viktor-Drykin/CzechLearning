//
//  VocabularyBootstrap.swift
//  CzechVocab / App
//
//  Решает, нужен ли импорт, и ведёт его на фоновом акторе, отдавая прогресс в UI.
//  Версия данных хранится в `UserDefaults` под ключом `dataVersion` (ТЗ 5.1).
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class VocabularyBootstrap {

    enum Phase: Equatable {
        /// Ещё не проверяли, нужен ли импорт.
        case idle
        case importing(progress: Double)
        case ready
        case failed(message: String)
    }

    private(set) var phase: Phase = .idle

    static let dataVersionKey = "dataVersion"

    private let container: ModelContainer
    private let defaults: UserDefaults

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
    }

    /// Импорт нужен при первом запуске и когда константа версии обогнала сохранённую.
    var needsImport: Bool {
        defaults.integer(forKey: Self.dataVersionKey) < VocabularyResource.dataVersion
    }

    func start() async {
        guard phase == .idle else { return }

        guard needsImport else {
            phase = .ready
            return
        }

        phase = .importing(progress: 0)

        do {
            let url = try VocabularyResource.url()
            let importer = DataImporter(modelContainer: container)

            // Импортёр зовёт колбэк с фонового актора — возвращаем прогресс на главный.
            let summary = try await importer.importVocabulary(from: url) { [weak self] value in
                Task { @MainActor in
                    self?.updateProgress(value)
                }
            }

            defaults.set(VocabularyResource.dataVersion, forKey: Self.dataVersionKey)
            phase = .ready
            _ = summary
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
    }

    /// Повторная попытка после ошибки.
    func retry() async {
        phase = .idle
        await start()
    }

    private func updateProgress(_ value: Double) {
        guard case .importing = phase else { return }
        phase = .importing(progress: value)
    }
}
