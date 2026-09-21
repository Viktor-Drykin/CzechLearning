//
//  TypingView.swift
//  CzechVocab / Features / Study / Modes
//
//  Письменный ввод: перевод в вопросе, чешское слово в ответе.
//  Фразы в этот режим не попадают — их отсеивает очередь сессии.
//

import SwiftUI

struct TypingView: View {

    let word: Word
    let language: TranslationLanguage
    let showImages: Bool
    let onAnswer: (AnswerValidator.Outcome) -> Void

    @State private var input = ""
    @State private var outcome: AnswerValidator.Outcome?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            prompt
                .frame(maxHeight: .infinity)

            answerField

            if let outcome {
                feedback(outcome)
                PrimaryButton(title: String(localized: "Дальше")) { advance() }
            } else {
                PrimaryButton(
                    title: String(localized: "Проверить"),
                    isEnabled: !input.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    check()
                }
                SecondaryButton(title: String(localized: "Не знаю")) { giveUp() }
            }
        }
        .task(id: word.id) { reset() }
    }

    // MARK: - Вопрос

    private var prompt: some View {
        VStack(spacing: AppSpacing.stack) {
            Spacer(minLength: 0)

            if showImages {
                WordImageView(word: word, height: ImagePlaceholder.Metrics.compactHeight)
            }

            Text(verbatim: word.translation(for: language))
                .appFont(AppFont.title1)
                .foregroundStyle(AppColor.label)
                .multilineTextAlignment(.center)

            Chip(word.partOfSpeech.shortName)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.cardPadding)
        .background(
            AppColor.surface,
            in: RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
        )
    }

    // MARK: - Поле ввода

    private var answerField: some View {
        TextField(text: $input) {
            Text("Чешское слово")
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
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                .strokeBorder(fieldBorder, lineWidth: 1)
        )
        .focused($isFocused)
        .disabled(outcome != nil)
        .onSubmit { check() }
        .accessibilityLabel(Text("Ответ по-чешски"))
    }

    private var fieldBorder: Color {
        switch outcome {
        case .correct: AppColor.success
        case .correctWithoutDiacritics, .almostCorrect: AppColor.warning
        case .incorrect, .gaveUp: AppColor.danger
        case nil: .clear
        }
    }

    // MARK: - Разбор ответа

    @ViewBuilder
    private func feedback(_ outcome: AnswerValidator.Outcome) -> some View {
        VStack(spacing: AppSpacing.tight) {
            Text(verbatim: message(for: outcome))
                .appFont(AppFont.subheadline)
                .foregroundStyle(messageTint(for: outcome))

            // Правильное написание с подсвеченной диакритикой.
            DiacriticHighlightText(word: word.czech)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.cardPaddingCompact)
        .background(
            AppColor.surfaceSecondary,
            in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
        )
    }

    private func message(for outcome: AnswerValidator.Outcome) -> String {
        switch outcome {
        case .correct: String(localized: "Верно")
        case .correctWithoutDiacritics: String(localized: "Верно, но без диакритики")
        case .almostCorrect: String(localized: "Почти верно — одна опечатка")
        case .incorrect: String(localized: "Неверно")
        case .gaveUp: String(localized: "Правильный ответ")
        }
    }

    private func messageTint(for outcome: AnswerValidator.Outcome) -> Color {
        switch outcome {
        case .correct: AppColor.grade(.good).label
        case .correctWithoutDiacritics, .almostCorrect: AppColor.grade(.hard).label
        case .incorrect, .gaveUp: AppColor.grade(.again).label
        }
    }

    // MARK: - Действия

    private func check() {
        guard outcome == nil else { return }
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isFocused = false
        outcome = AnswerValidator.validate(answer: trimmed, expected: word.czech)
    }

    private func giveUp() {
        guard outcome == nil else { return }
        isFocused = false
        outcome = .gaveUp
    }

    private func advance() {
        guard let outcome else { return }
        onAnswer(outcome)
    }

    private func reset() {
        input = ""
        outcome = nil
        isFocused = true
    }
}

// MARK: - Подсветка диакритики

/// Правильное написание, в котором диакритические знаки выделены цветом:
/// именно их пользователь чаще всего пропускает.
struct DiacriticHighlightText: View {

    let word: String

    var body: some View {
        Text(attributed)
            .appFont(AppFont.title1)
            .accessibilityLabel(Text.czech(word))
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        for part in AnswerValidator.highlightDiacritics(in: word) {
            var piece = AttributedString(String(part.character))
            piece.foregroundColor = part.isDiacritic ? AppColor.warning : AppColor.label
            result.append(piece)
        }
        result.languageIdentifier = "cs-CZ"
        return result
    }
}
