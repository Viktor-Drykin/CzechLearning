//
//  FlashcardView.swift
//  CzechVocab / Features / Study / Modes
//
//  Базовый режим. Лицевая сторона — слово (или перевод, если направление
//  обратное), оборот — полный разбор и четыре кнопки оценки.
//

import SwiftUI

struct FlashcardView: View {

    let word: Word
    let direction: CardDirection
    let language: TranslationLanguage
    let showImages: Bool
    let clozeEnabled: Bool
    let intervals: [ReviewGrade: String]
    let onGrade: (ReviewGrade) -> Void

    @Environment(SpeechService.self) private var speech
    @Environment(SettingsStore.self) private var settings

    @State private var isRevealed = false

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            card
                .frame(maxHeight: .infinity)

            footer
        }
        .onChange(of: word.id) { _, _ in
            isRevealed = false
        }
        .task(id: word.id) { autoSpeak() }
    }

    /// Автоозвучка при показе карточки (ТЗ 8.4). В обратном направлении
    /// на лице стоит перевод — озвучивать нечего.
    private func autoSpeak() {
        guard settings.autoSpeak, !isReverse else { return }
        speech.speak(word.czech, rateMultiplier: settings.speechRateMultiplier)
    }

    // MARK: - Карточка

    private var card: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                if isRevealed {
                    backContent
                } else {
                    frontContent
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.cardPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            AppColor.surface,
            in: RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
        )
    }

    // MARK: - Лицо

    @ViewBuilder
    private var frontContent: some View {
        VStack(spacing: AppSpacing.stack) {
            Spacer(minLength: 0)

            if showImages, !isReverse {
                WordImageView(word: word, height: ImagePlaceholder.Metrics.defaultHeight)
            }

            if clozeEnabled, !isReverse, let cloze = ClozeBuilder.build(for: word) {
                clozePrompt(cloze)
            } else {
                promptText
            }

            if !isReverse {
                SpeakButton(text: word.czech)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var promptText: some View {
        if isReverse {
            // В обратном направлении на лице стоит перевод: род подсказывать
            // нечему, слово пользователь ещё не вспомнил.
            Text(verbatim: word.translation(for: language))
                .appFont(AppFont.answerDisplay)
                .foregroundStyle(AppColor.label)
                .multilineTextAlignment(.center)
        } else {
            Text.czech(word.czech)
                .appFont(AppFont.wordDisplay)
                .czechHeadword(word.nounGender)
                .multilineTextAlignment(.center)
        }
    }

    /// Cloze-формат: пример с пропуском вместо самого слова (ТЗ 7.6).
    private func clozePrompt(_ cloze: ClozeBuilder.Cloze) -> some View {
        VStack(spacing: AppSpacing.stack) {
            Text.czech(cloze.sentence)
                .appFont(AppFont.title2)
                .foregroundStyle(AppColor.label)
                .multilineTextAlignment(.center)

            Text(verbatim: word.primaryTranslation(for: language))
                .appFont(AppFont.subheadline)
                .foregroundStyle(AppColor.labelTertiary)
        }
    }

    // MARK: - Оборот

    private var backContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.stack) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.tight) {
                Text.czech(word.czech)
                    .appFont(AppFont.title1)
                    .czechHeadword(word.nounGender)

                Spacer(minLength: 0)

                SpeakButton(text: word.czech)
            }

            Text(verbatim: word.translation(for: language))
                .appFont(AppFont.answerDisplay)
                .foregroundStyle(AppColor.label)
                .fixedSize(horizontal: false, vertical: true)

            WordChipRow(word: word)

            if let note = word.noteText {
                NoteCallout(text: note)
            }

            ExampleList(word: word, language: language)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Низ экрана

    @ViewBuilder
    private var footer: some View {
        if isRevealed {
            GradeButtonRow(intervals: intervals) { grade in
                isRevealed = false
                onGrade(grade)
            }
        } else {
            PrimaryButton(title: String(localized: "Показать ответ")) {
                withAnimation(.easeOut(duration: 0.18)) { isRevealed = true }
            }
        }
    }

    private var isReverse: Bool {
        direction == .translationToCzech
    }
}

// MARK: - Примеры

/// Два примера с переводами. Общий блок для карточки, каталога и режимов.
struct ExampleList: View {

    let word: Word
    let language: TranslationLanguage
    var showSpeakButtons = true

    var body: some View {
        VStack(spacing: AppSpacing.tight) {
            ForEach(Array(word.examples(for: language).enumerated()), id: \.offset) { _, example in
                ExampleRow(
                    czech: example.czech,
                    translated: example.translated,
                    showSpeakButton: showSpeakButtons
                )
            }
        }
    }
}

struct ExampleRow: View {

    let czech: String
    let translated: String
    var showSpeakButton = true

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.tight) {
            VStack(alignment: .leading, spacing: 2) {
                Text.czech(czech)
                    .appFont(AppFont.subheadline)
                    .foregroundStyle(AppColor.label)

                Text(verbatim: translated)
                    .appFont(AppFont.subheadline)
                    .foregroundStyle(AppColor.labelSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showSpeakButton {
                SpeakButton(text: czech, style: .compact)
            }
        }
        .padding(AppSpacing.cardPaddingCompact)
        .background(
            AppColor.surfaceSecondary,
            in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
        )
    }
}
