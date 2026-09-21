//
//  SpeechServiceTests.swift
//  CzechLearningTests
//
//  Озвучка проверяется настолько, насколько это возможно без звука:
//  что сервис поднимается, определяет наличие голоса и не падает,
//  когда чешского голоса в системе нет.
//

import AVFoundation
import Foundation
import Testing

@testable import CzechLearning

@Suite("Озвучка")
@MainActor
struct SpeechServiceTests {

    @Test("Сервис поднимается и определяет наличие чешского голоса")
    func detectsVoice() {
        let service = SpeechService()
        let expected = AVSpeechSynthesisVoice.speechVoices().contains { $0.language.hasPrefix("cs") }
        #expect(service.isCzechVoiceAvailable == expected)
    }

    @Test("Без чешского голоса и с пустой строкой вызов не падает")
    func speakingIsSafe() {
        let service = SpeechService()
        service.speak("")
        service.speak("Dobrý den")
        service.speakSlowly("Dobrý den")
        service.stop()
        #expect(Bool(true), "Вызовы завершились без исключений")
    }

    @Test("Подсказка про установку голоса непустая и указывает путь в настройках")
    func missingVoiceHint() {
        #expect(SpeechService.missingVoiceHint.contains("Универсальный доступ"))
        #expect(SpeechService.missingVoiceHint.contains("Голоса"))
    }

    @Test(
        "Скорость из настроек переводится в множитель: 0.5 — это норма ×0.9",
        arguments: [
            (0.4, 0.72),
            (0.5, 0.9),
            (0.6, 1.08),
        ]
    )
    func rateMultiplier(setting: Double, expected: Double) {
        let suite = UserDefaults(suiteName: "speech.\(UUID().uuidString)") ?? .standard
        let settings = SettingsStore(defaults: suite)
        settings.speechRate = setting
        #expect(abs(settings.speechRateMultiplier - expected) < 0.0001)
    }

    @Test("Замедленный режим — 0.6 от системной скорости")
    func slowRate() {
        #expect(SpeechService.slowRateMultiplier == 0.6)
        #expect(SpeechService.defaultRateMultiplier == 0.9)
        #expect(SpeechService.languageCode == "cs-CZ")
    }
}

@Suite("Настройки")
@MainActor
struct SettingsStoreTests {

    private func makeStore() -> SettingsStore {
        let suite = UserDefaults(suiteName: "settings.\(UUID().uuidString)") ?? .standard
        return SettingsStore(defaults: suite)
    }

    @Test("Значения по умолчанию соответствуют таблице 8.4 ТЗ")
    func defaults() {
        let settings = makeStore()
        #expect(settings.translationLanguage == .russian)
        #expect(settings.newCardsPerDay == 10)
        #expect(settings.reviewsPerDay == 200)
        #expect(settings.defaultMode == .flashcards)
        #expect(settings.cardDirection == .czechToTranslation)
        #expect(settings.autoSpeak)
        #expect(settings.speechRate == 0.5)
        #expect(settings.showImages)
        #expect(settings.clozeEnabled == false)
    }

    @Test("Настройки переживают пересоздание хранилища")
    func persists() {
        let name = "settings.\(UUID().uuidString)"
        let suite = try? #require(UserDefaults(suiteName: name))

        let first = SettingsStore(defaults: suite ?? .standard)
        first.translationLanguage = .ukrainian
        first.newCardsPerDay = 30
        first.clozeEnabled = true

        let second = SettingsStore(defaults: suite ?? .standard)
        #expect(second.translationLanguage == .ukrainian)
        #expect(second.newCardsPerDay == 30)
        #expect(second.clozeEnabled)
    }

    @Test("Сброс возвращает значения по умолчанию")
    func resets() {
        let settings = makeStore()
        settings.translationLanguage = .ukrainian
        settings.showImages = false
        settings.resetToDefaults()

        #expect(settings.translationLanguage == .russian)
        #expect(settings.showImages)
    }

    @Test("Смешанное направление разворачивается в одно из двух")
    func mixedDirectionResolves() {
        #expect(CardDirection.mixed.resolved(random: { true }) == .czechToTranslation)
        #expect(CardDirection.mixed.resolved(random: { false }) == .translationToCzech)
        #expect(CardDirection.czechToTranslation.resolved(random: { false }) == .czechToTranslation)
        #expect(CardDirection.translationToCzech.resolved(random: { true }) == .translationToCzech)
    }
}
