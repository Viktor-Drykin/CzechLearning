//
//  SpeechService.swift
//  CzechVocab / Services
//
//  Озвучка чешского через системный TTS (ТЗ раздел 9).
//
//  Русский и украинский текст не озвучиваем: системные голоса читают чешские
//  слова в переводах неверно, а сами переводы пользователь и так читает глазами.
//

import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class SpeechService {

    /// Чешский голос установлен в системе. Если нет — кнопки озвучки и режим
    /// аудирования скрываются, а в настройках показывается подсказка.
    private(set) var isCzechVoiceAvailable: Bool

    /// Сейчас что-то произносится — для подсветки кнопки.
    private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SpeechDelegate()

    static let languageCode = "cs-CZ"
    /// Скорость по умолчанию: системная × 0.9 (ТЗ 9).
    static let defaultRateMultiplier = 0.9
    /// Замедленный режим.
    static let slowRateMultiplier = 0.6

    init() {
        isCzechVoiceAvailable = Self.detectCzechVoice()
        synthesizer.delegate = delegate
        delegate.onChange = { [weak self] speaking in
            self?.isSpeaking = speaking
        }
    }

    // MARK: - Произнесение

    /// Произносит чешский текст. Предыдущее произнесение прерывается.
    /// - Parameter rateMultiplier: множитель к системной скорости; `nil` — значение по умолчанию.
    func speak(_ text: String, rateMultiplier: Double? = nil) {
        guard isCzechVoiceAvailable, !text.isEmpty else { return }

        stop()
        activateSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.languageCode)
        utterance.rate = Float(
            Double(AVSpeechUtteranceDefaultSpeechRate) * (rateMultiplier ?? Self.defaultRateMultiplier)
        )
        synthesizer.speak(utterance)
    }

    /// Медленное произнесение — кнопка в режиме аудирования.
    func speakSlowly(_ text: String) {
        speak(text, rateMultiplier: Self.slowRateMultiplier)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Аудиосессия

    /// Сессия активируется только на время произнесения и не глушит чужую музыку.
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            // Аудиосессия не поднялась — озвучка просто не прозвучит,
            // блокировать карточку из-за этого нельзя.
        }
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - Голос

    private static func detectCzechVoice() -> Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { $0.language.hasPrefix("cs") }
    }

    /// Подсказка для настроек, когда голос не установлен.
    static let missingVoiceHint = String(
        localized: "Установите чешский голос: Настройки → Универсальный доступ → Устный контент → Голоса"
    )
}

// MARK: - Делегат

/// `AVSpeechSynthesizerDelegate` требует класс NSObject; держим его отдельно,
/// чтобы сервис оставался `@Observable` без наследования.
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {

    /// Колбэк ставится один раз при инициализации сервиса и дальше не меняется;
    /// синтезатор зовёт делегат с главной очереди.
    @MainActor private var _onChange: (@MainActor (Bool) -> Void)?

    @MainActor
    var onChange: (@MainActor (Bool) -> Void)? {
        get { _onChange }
        set { _onChange = newValue }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        notify(true)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        notify(false)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        notify(false)
    }

    private nonisolated func notify(_ speaking: Bool) {
        Task { @MainActor in
            onChange?(speaking)
        }
    }
}
