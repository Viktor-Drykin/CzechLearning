//
//  ListeningView.swift
//  CzechVocab / Features / Study / Modes
//
//  Аудирование: слово проигрывается автоматически, пользователь выбирает
//  перевод или вводит услышанное. Режим скрыт, если чешского голоса нет.
//

import SwiftUI

struct ListeningView: View {

    let word: Word
    let dictionary: [DistractorCandidate]
    let language: TranslationLanguage
    let usesTyping: Bool
    let onChoice: (Bool) -> Void
    let onTyped: (AnswerValidator.Outcome) -> Void

    @Environment(SpeechService.self) private var speech
    @Environment(SettingsStore.self) private var settings

    @State private var options: [DistractorCandidate] = []
    @State private var selectedID: Int?
    @State private var input = ""
    @State private var outcome: AnswerValidator.Outcome?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            player
                .frame(maxHeight: .infinity)

            if usesTyping {
                typingAnswer
            } else {
                choiceAnswer
            }
        }
        .task(id: word.id) { await prepare() }
    }

    // MARK: - Плеер

    private var player: some View {
        VStack(spacing: AppSpacing.stack) {
            Spacer(minLength: 0)

            Button {
                speech.speak(word.czech, rateMultiplier: settings.speechRateMultiplier)
            } label: {
                Image(systemName: speech.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .appSymbol(AppSymbol.listen)
                    .foregroundStyle(AppColor.accent)
                    .frame(width: AppSize.listenButton, height: AppSize.listenButton)
                    .background(AppColor.accentTint, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Прослушать ещё раз"))

            Button {
                speech.speakSlowly(word.czech)
            } label: {
                HStack(spacing: AppSpacing.tight) {
                    Image(systemName: "tortoise.fill")
                    Text("Помедленнее")
                }
                .appFont(AppFont.footnote)
                .foregroundStyle(AppColor.accent)
            }
            .buttonStyle(.plain)
            .minimumTouchTarget()

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.cardPadding)
        .background(
            AppColor.surface,
            in: RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
        )
    }

    // MARK: - Ответ выбором

    private var choiceAnswer: some View {
        VStack(spacing: AppSpacing.tight) {
            ForEach(options) { option in
                OptionRow(
                    text: option.primaryTranslation(for: language),
                    state: state(for: option),
                    action: { select(option) }
                )
            }

            if selectedID != nil {
                PrimaryButton(title: String(localized: "Дальше")) {
                    onChoice(selectedID == word.id)
                }
            }
        }
    }

    private func state(for option: DistractorCandidate) -> OptionRow.State {
        guard let selectedID else { return .idle }
        if option.id == word.id { return .correct }
        if option.id == selectedID { return .wrong }
        return .dimmed
    }

    private func select(_ option: DistractorCandidate) {
        guard selectedID == nil else { return }
        selectedID = option.id
    }

    // MARK: - Ответ вводом

    private var typingAnswer: some View {
        VStack(spacing: AppSpacing.tight) {
            TextField(text: $input) {
                Text("Что вы услышали?")
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .appFont(AppFont.body)
            .foregroundStyle(AppColor.label)
            .padding(.horizontal, AppSpacing.cardPaddingCompact)
            .frame(height: AppSize.buttonSession)
            .background(
                AppColor.fill,
                in: RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
            )
            .focused($isFocused)
            .disabled(outcome != nil)
            .accessibilityLabel(Text("Услышанное слово"))

            if let outcome {
                DiacriticHighlightText(word: word.czech)
                PrimaryButton(title: String(localized: "Дальше")) { onTyped(outcome) }
            } else {
                PrimaryButton(
                    title: String(localized: "Проверить"),
                    isEnabled: !input.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    outcome = AnswerValidator.validate(answer: input, expected: word.czech)
                    isFocused = false
                }
                SecondaryButton(title: String(localized: "Не знаю")) {
                    outcome = .gaveUp
                    isFocused = false
                }
            }
        }
    }

    // MARK: - Подготовка

    private func prepare() async {
        selectedID = nil
        input = ""
        outcome = nil

        options = DistractorGenerator.options(
            for: DistractorCandidate(word: word),
            in: dictionary,
            language: language
        )

        // Слово проигрывается само — это суть режима.
        speech.speak(word.czech, rateMultiplier: settings.speechRateMultiplier)
    }
}
