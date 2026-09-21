//
//  MultipleChoiceView.swift
//  CzechVocab / Features / Study / Modes
//
//  Выбор варианта: вопрос и четыре ответа. Оценка считается по времени
//  ответа (ТЗ 6.3), четыре кнопки оценки не показываются.
//

import SwiftUI

struct MultipleChoiceView: View {

    let word: Word
    let dictionary: [DistractorCandidate]
    let direction: CardDirection
    let language: TranslationLanguage
    let onAnswer: (Bool) -> Void

    @State private var options: [DistractorCandidate] = []
    @State private var selectedID: Int?

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            question
                .frame(maxHeight: .infinity)

            VStack(spacing: AppSpacing.tight) {
                ForEach(options) { option in
                    OptionRow(
                        text: optionText(for: option),
                        isCzech: isReverse,
                        state: state(for: option),
                        action: { select(option) }
                    )
                }
            }

            if selectedID != nil {
                PrimaryButton(title: String(localized: "Дальше")) { advance() }
            }
        }
        .task(id: word.id) { buildOptions() }
    }

    // MARK: - Вопрос

    private var question: some View {
        VStack(spacing: AppSpacing.stack) {
            Spacer(minLength: 0)

            if isReverse {
                Text(verbatim: word.primaryTranslation(for: language))
                    .appFont(AppFont.wordDisplayCompact)
            } else {
                Text.czech(word.czech)
                    .appFont(AppFont.wordDisplayCompact)
            }

            if !isReverse {
                SpeakButton(text: word.czech)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(AppColor.label)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.cardPadding)
        .background(
            AppColor.surface,
            in: RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
        )
        // Опознавательный знак режима для UI-тестов: собственного текста,
        // по которому режим отличим, на экране нет.
        .accessibilityIdentifier("mode.multipleChoice")
    }

    // MARK: - Варианты

    private func optionText(for option: DistractorCandidate) -> String {
        isReverse ? option.czech : option.primaryTranslation(for: language)
    }

    private func state(for option: DistractorCandidate) -> OptionRow.State {
        guard let selectedID else { return .idle }
        if option.id == word.id { return .correct }
        if option.id == selectedID { return .wrong }
        return .dimmed
    }

    private func buildOptions() {
        selectedID = nil
        let target = DistractorCandidate(word: word)
        options = DistractorGenerator.options(
            for: target,
            in: dictionary,
            language: language
        )
    }

    private func select(_ option: DistractorCandidate) {
        guard selectedID == nil else { return }
        selectedID = option.id
    }

    private func advance() {
        guard let selectedID else { return }
        onAnswer(selectedID == word.id)
    }

    private var isReverse: Bool {
        direction == .translationToCzech
    }
}

// MARK: - Строка варианта

struct OptionRow: View {

    enum State {
        case idle
        case correct
        case wrong
        case dimmed
    }

    let text: String
    var isCzech = false
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isCzech {
                    Text.czech(text)
                } else {
                    Text(verbatim: text)
                }
                Spacer(minLength: 0)

                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .appFont(AppFont.body)
            .foregroundStyle(foreground)
            .padding(.horizontal, AppSpacing.cardPaddingCompact)
            .frame(maxWidth: .infinity, minHeight: AppSize.optionRow)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
    }

    private var foreground: Color {
        switch state {
        case .idle: AppColor.label
        case .correct: AppColor.grade(.good).label
        case .wrong: AppColor.grade(.again).label
        case .dimmed: AppColor.labelTertiary
        }
    }

    private var background: Color {
        switch state {
        case .idle, .dimmed: AppColor.surface
        case .correct: AppColor.grade(.good).background
        case .wrong: AppColor.grade(.again).background
        }
    }
}
