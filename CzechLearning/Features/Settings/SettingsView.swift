//
//  SettingsView.swift
//  CzechVocab / Features / Settings
//
//  Вся таблица 8.4 ТЗ. Значения пишутся в SettingsStore сразу, поэтому
//  следующая сессия видит их без перезапуска.
//

import SwiftData
import SwiftUI

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(SpeechService.self) private var speech

    @State private var showsResetConfirmation = false
    @State private var showsFinalResetConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                translationSection($settings)
                limitsSection($settings)
                sessionSection($settings)
                speechSection($settings)
                appearanceSection($settings)
                resetSection
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle(Text("Настройки"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Готово") }
                }
            }
        }
    }

    // MARK: - Язык перевода

    private func translationSection(_ settings: Bindable<SettingsStore>) -> some View {
        Section {
            Picker(selection: settings.translationLanguage) {
                ForEach(TranslationLanguage.allCases, id: \.rawValue) { language in
                    Text(verbatim: language.displayName).tag(language)
                }
            } label: {
                Text("Язык перевода")
            }
        } header: {
            Text("Перевод")
        } footer: {
            Text("Не связан с языком интерфейса: можно держать интерфейс на украинском, а переводы смотреть на русском.")
        }
    }

    // MARK: - Лимиты

    private func limitsSection(_ settings: Bindable<SettingsStore>) -> some View {
        Section {
            Picker(selection: settings.newCardsPerDay) {
                ForEach(SettingsStore.newCardOptions, id: \.self) { value in
                    Text(verbatim: Self.limitTitle(value)).tag(value)
                }
            } label: {
                Text("Новых слов в день")
            }

            Picker(selection: settings.reviewsPerDay) {
                ForEach(SettingsStore.reviewOptions, id: \.self) { value in
                    Text(verbatim: Self.limitTitle(value)).tag(value)
                }
            } label: {
                Text("Максимум повторений")
            }
        } header: {
            Text("Нагрузка")
        }
    }

    private static func limitTitle(_ value: Int) -> String {
        value == SRSConstants.unlimited
            ? String(localized: "Без лимита")
            : "\(value)"
    }

    // MARK: - Сессия

    private func sessionSection(_ settings: Bindable<SettingsStore>) -> some View {
        Section {
            Picker(selection: settings.defaultMode) {
                ForEach(availableModes, id: \.rawValue) { mode in
                    Text(verbatim: mode.displayName).tag(mode)
                }
            } label: {
                Text("Режим по умолчанию")
            }

            Picker(selection: settings.cardDirection) {
                Text("CZ → перевод").tag(CardDirection.czechToTranslation)
                Text("Перевод → CZ").tag(CardDirection.translationToCzech)
                Text("Смешанное").tag(CardDirection.mixed)
            } label: {
                Text("Направление карточек")
            }

            Toggle(isOn: settings.clozeEnabled) {
                Text("Пропуск в предложении")
            }

            if speech.isCzechVoiceAvailable {
                Toggle(isOn: settings.listeningUsesTyping) {
                    Text("В аудировании вводить ответ")
                }
            }
        } header: {
            Text("Сессия")
        } footer: {
            Text("Пропуск в предложении показывает пример с пробелом вместо слова. Доступен не для всех слов.")
        }
    }

    // MARK: - Озвучка

    private func speechSection(_ settings: Bindable<SettingsStore>) -> some View {
        Section {
            if speech.isCzechVoiceAvailable {
                Toggle(isOn: settings.autoSpeak) {
                    Text("Автоозвучка карточки")
                }

                Picker(selection: settings.speechRate) {
                    Text("Медленно").tag(0.4)
                    Text("Обычно").tag(0.5)
                    Text("Быстро").tag(0.6)
                } label: {
                    Text("Скорость озвучки")
                }
            } else {
                Text(verbatim: SpeechService.missingVoiceHint)
                    .appFont(AppFont.footnote)
                    .foregroundStyle(AppColor.labelSecondary)
            }
        } header: {
            Text("Озвучка")
        }
    }

    // MARK: - Оформление

    private func appearanceSection(_ settings: Bindable<SettingsStore>) -> some View {
        Section {
            Toggle(isOn: settings.showImages) {
                Text("Показывать картинки")
            }
        } header: {
            Text("Оформление")
        } footer: {
            Text("Картинки загружаются один раз и дальше берутся с диска. Без сети показывается заглушка.")
        }
    }

    // MARK: - Сброс

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Text("Сбросить прогресс")
            }
        } footer: {
            Text("Удаляет статус изучения всех слов, журнал ответов и статистику. Словарь останется на месте.")
        }
        .confirmationDialog(
            Text("Сбросить весь прогресс?"),
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Продолжить"), role: .destructive) {
                showsFinalResetConfirmation = true
            }
            Button(String(localized: "Отмена"), role: .cancel) {}
        } message: {
            Text("Действие необратимо.")
        }
        .confirmationDialog(
            Text("Точно сбросить?"),
            isPresented: $showsFinalResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Сбросить"), role: .destructive) { resetProgress() }
            Button(String(localized: "Отмена"), role: .cancel) {}
        } message: {
            Text("Выученные слова снова станут новыми.")
        }
    }

    /// Аудирование скрывается, когда чешского голоса нет (ТЗ 7.4).
    private var availableModes: [StudyMode] {
        StudyMode.allCases.filter { $0 != .listening || speech.isCzechVoiceAvailable }
    }

    private func resetProgress() {
        try? StatsRepository(context: modelContext).resetAllProgress()
        Task { await ImageCacheService.shared.clear() }
        dismiss()
    }
}
