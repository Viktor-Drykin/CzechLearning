//
//  WordDetailView.swift
//  CzechVocab / Features / Catalog
//
//  Полная карточка слова: все переводы, грамматика, примечание, примеры
//  с озвучкой, статус изучения и управление ротацией.
//

import SwiftData
import SwiftUI

struct WordDetailView: View {

    let word: Word

    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings

    @State private var isSuspended = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                header
                translations
                if let note = word.noteText {
                    NoteCallout(text: note)
                }
                examples
                studyStatus
            }
            .padding(.horizontal, AppSpacing.screenInset)
            .padding(.vertical, AppSpacing.stack)
        }
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { isSuspended = word.progress?.isSuspended ?? false }
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.stack) {
            if settings.showImages {
                WordImageView(word: word)
            }

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.stack) {
                Text.czech(word.czech)
                    .appFont(AppFont.wordDisplayCompact)
                    .czechHeadword(word.nounGender)

                Spacer(minLength: 0)

                SpeakButton(text: word.czech)
            }

            WordChipRow(word: word)
        }
    }

    // MARK: - Переводы

    private var translations: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            SectionHeader(title: String(localized: "Переводы"))

            VStack(spacing: 0) {
                TranslationRow(language: String(localized: "Русский"), value: word.russian)
                Divider().overlay(AppColor.separator)
                TranslationRow(language: String(localized: "Українська"), value: word.ukrainian)
                if let english = word.english {
                    Divider().overlay(AppColor.separator)
                    TranslationRow(language: String(localized: "English"), value: english)
                }
            }
            .cardSurface()
        }
    }

    // MARK: - Примеры

    private var examples: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            SectionHeader(title: String(localized: "Примеры"))
            ExampleList(word: word, language: settings.translationLanguage)
        }
    }

    // MARK: - Статус изучения

    private var studyStatus: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            SectionHeader(title: String(localized: "Изучение"))

            VStack(spacing: 0) {
                DetailRow(
                    title: String(localized: "Статус"),
                    value: statusText,
                    valueTint: statusTint
                )

                if let progress = word.progress, progress.totalReviews > 0 {
                    Divider().overlay(AppColor.separator)
                    DetailRow(
                        title: String(localized: "Ответов"),
                        value: "\(progress.correctReviews) / \(progress.totalReviews)"
                    )
                    Divider().overlay(AppColor.separator)
                    DetailRow(
                        title: String(localized: "Следующий показ"),
                        value: progress.dueDate.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
            .cardSurface()

            if isSuspended {
                SecondaryButton(
                    title: String(localized: "Вернуть в изучение"),
                    systemImage: "arrow.clockwise"
                ) {
                    setSuspended(false)
                }
            } else {
                SecondaryButton(
                    title: String(localized: "Исключить из ротации"),
                    systemImage: "pause.circle",
                    tint: AppColor.danger
                ) {
                    setSuspended(true)
                }
            }
        }
    }

    private var statusText: String {
        guard let progress = word.progress else { return String(localized: "Не начато") }
        if progress.isSuspended { return String(localized: "Исключено из ротации") }
        if progress.isLearned { return String(localized: "Выучено") }
        if progress.isInProgress { return String(localized: "В изучении") }
        return String(localized: "Не начато")
    }

    private var statusTint: Color {
        guard let progress = word.progress, !progress.isSuspended else {
            return AppColor.labelSecondary
        }
        if progress.isLearned { return AppColor.success }
        if progress.isInProgress { return AppColor.warning }
        return AppColor.labelSecondary
    }

    private func setSuspended(_ suspended: Bool) {
        let repository = WordRepository(context: modelContext)
        repository.setSuspended(suspended, for: word)
        try? repository.save()
        isSuspended = suspended
    }
}

// MARK: - Составные части

struct SectionHeader: View {

    let title: String

    var body: some View {
        Text(verbatim: title)
            .appFont(AppFont.sectionHeader)
            .textCase(.uppercase)
            .foregroundStyle(AppColor.labelTertiary)
    }
}

private struct TranslationRow: View {

    let language: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.stack) {
            Text(verbatim: language)
                .appFont(AppFont.callout)
                .foregroundStyle(AppColor.labelTertiary)
                .frame(width: Metrics.labelWidth, alignment: .leading)

            Text(verbatim: value)
                .appFont(AppFont.callout)
                .foregroundStyle(AppColor.label)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.rowInset)
        .padding(.vertical, AppSpacing.tight)
        .frame(minHeight: AppSize.listRow)
        .accessibilityElement(children: .combine)
    }

    private enum Metrics {
        static let labelWidth: CGFloat = 100
    }
}

struct DetailRow: View {

    let title: String
    let value: String
    var valueTint: Color = AppColor.labelSecondary

    var body: some View {
        HStack(spacing: AppSpacing.stack) {
            Text(verbatim: title)
                .appFont(AppFont.callout)
                .foregroundStyle(AppColor.label)

            Spacer(minLength: 0)

            Text(verbatim: value)
                .appFont(AppFont.callout)
                .foregroundStyle(valueTint)
        }
        .padding(.horizontal, AppSpacing.rowInset)
        .frame(height: AppSize.listRow)
        .accessibilityElement(children: .combine)
    }
}
