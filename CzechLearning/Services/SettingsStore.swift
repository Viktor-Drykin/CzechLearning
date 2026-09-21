//
//  SettingsStore.swift
//  CzechVocab / Services
//
//  Настройки приложения поверх UserDefaults. Единственный экземпляр кладётся
//  в окружение, поэтому смена языка перевода или лимитов видна во всех режимах
//  сразу, без перезапуска (критерий приёмки из раздела 15 ТЗ).
//

import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {

    // MARK: - Ключи

    private enum Key {
        static let translationLanguage = "settings.translationLanguage"
        static let newCardsPerDay = "settings.newCardsPerDay"
        static let reviewsPerDay = "settings.reviewsPerDay"
        static let defaultMode = "settings.defaultMode"
        static let cardDirection = "settings.cardDirection"
        static let autoSpeak = "settings.autoSpeak"
        static let speechRate = "settings.speechRate"
        static let showImages = "settings.showImages"
        static let clozeEnabled = "settings.clozeEnabled"
        static let listeningUsesTyping = "settings.listeningUsesTyping"
    }

    /// Допустимые значения лимитов из таблицы 8.4.
    nonisolated static let newCardOptions = [5, 10, 20, 30, SRSConstants.unlimited]
    nonisolated static let reviewOptions = [50, 100, 200, SRSConstants.unlimited]
    /// Скорость озвучки: множитель к `AVSpeechUtteranceDefaultSpeechRate`.
    nonisolated static let speechRateOptions = [0.4, 0.5, 0.6]

    private let defaults: UserDefaults

    // MARK: - Значения

    var translationLanguage: TranslationLanguage {
        didSet { defaults.set(translationLanguage.rawValue, forKey: Key.translationLanguage) }
    }

    var newCardsPerDay: Int {
        didSet { defaults.set(newCardsPerDay, forKey: Key.newCardsPerDay) }
    }

    var reviewsPerDay: Int {
        didSet { defaults.set(reviewsPerDay, forKey: Key.reviewsPerDay) }
    }

    var defaultMode: StudyMode {
        didSet { defaults.set(defaultMode.rawValue, forKey: Key.defaultMode) }
    }

    var cardDirection: CardDirection {
        didSet { defaults.set(cardDirection.rawValue, forKey: Key.cardDirection) }
    }

    var autoSpeak: Bool {
        didSet { defaults.set(autoSpeak, forKey: Key.autoSpeak) }
    }

    var speechRate: Double {
        didSet { defaults.set(speechRate, forKey: Key.speechRate) }
    }

    var showImages: Bool {
        didSet { defaults.set(showImages, forKey: Key.showImages) }
    }

    /// Формат cloze на обороте карточки.
    var clozeEnabled: Bool {
        didSet { defaults.set(clozeEnabled, forKey: Key.clozeEnabled) }
    }

    /// В аудировании вводить услышанное вместо выбора из вариантов.
    var listeningUsesTyping: Bool {
        didSet { defaults.set(listeningUsesTyping, forKey: Key.listeningUsesTyping) }
    }

    // MARK: - Инициализация

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        translationLanguage = defaults.string(forKey: Key.translationLanguage)
            .flatMap(TranslationLanguage.init(rawValue:)) ?? .russian
        newCardsPerDay = defaults.object(forKey: Key.newCardsPerDay) as? Int
            ?? SRSConstants.defaultNewCardsPerDay
        reviewsPerDay = defaults.object(forKey: Key.reviewsPerDay) as? Int
            ?? SRSConstants.defaultReviewsPerDay
        defaultMode = defaults.string(forKey: Key.defaultMode)
            .flatMap(StudyMode.init(rawValue:)) ?? .flashcards
        cardDirection = defaults.string(forKey: Key.cardDirection)
            .flatMap(CardDirection.init(rawValue:)) ?? .czechToTranslation
        autoSpeak = defaults.object(forKey: Key.autoSpeak) as? Bool ?? true
        speechRate = defaults.object(forKey: Key.speechRate) as? Double ?? 0.5
        showImages = defaults.object(forKey: Key.showImages) as? Bool ?? true
        clozeEnabled = defaults.bool(forKey: Key.clozeEnabled)
        listeningUsesTyping = defaults.bool(forKey: Key.listeningUsesTyping)
    }

    /// Множитель к системной скорости речи. В настройках 0.5 — «норма»,
    /// а норма по ТЗ — системная скорость × 0.9; отсюда пропорция.
    var speechRateMultiplier: Double {
        speechRate / 0.5 * SpeechService.defaultRateMultiplier
    }

    /// Сбрасывает настройки к значениям по умолчанию. Прогресс не трогает.
    func resetToDefaults() {
        translationLanguage = .russian
        newCardsPerDay = SRSConstants.defaultNewCardsPerDay
        reviewsPerDay = SRSConstants.defaultReviewsPerDay
        defaultMode = .flashcards
        cardDirection = .czechToTranslation
        autoSpeak = true
        speechRate = 0.5
        showImages = true
        clozeEnabled = false
        listeningUsesTyping = false
    }
}
