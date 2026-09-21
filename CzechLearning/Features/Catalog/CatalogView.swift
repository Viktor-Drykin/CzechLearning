//
//  CatalogView.swift
//  CzechVocab / Features / Catalog
//
//  Вкладка «Словарь»: поиск, фильтр по уровню, разделы по темам.
//

import SwiftData
import SwiftUI

struct CatalogView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings

    @State private var viewModel: CatalogViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView().tint(AppColor.accent)
                }
            }
            .background(AppColor.background)
            .navigationTitle(Text("Словарь"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: CatalogViewModel.Section.self) { section in
                if let viewModel {
                    WordListView(
                        title: section.title,
                        words: viewModel.words(in: section)
                    )
                }
            }
            .navigationDestination(for: Word.self) { word in
                WordDetailView(word: word)
            }
        }
        .task { load() }
    }

    @ViewBuilder
    private func content(_ viewModel: CatalogViewModel) -> some View {
        @Bindable var model = viewModel

        ScrollView {
            LazyVStack(spacing: AppSpacing.stack, pinnedViews: []) {
                LevelSegmentedControl(selection: $model.levelFilter)
                    .padding(.top, AppSpacing.tight)

                if viewModel.isSearching {
                    searchResults(viewModel)
                } else {
                    sectionList(viewModel)
                }
            }
            .padding(.horizontal, AppSpacing.screenInset)
            .padding(.bottom, AppSpacing.stack)
        }
        .searchable(
            text: $model.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Слово, перевод или фраза")
        )
    }

    // MARK: - Результаты поиска

    @ViewBuilder
    private func searchResults(_ viewModel: CatalogViewModel) -> some View {
        if viewModel.results.isEmpty {
            EmptyStateView(
                symbolName: "magnifyingglass",
                title: String(localized: "Ничего не найдено"),
                message: String(localized: "Попробуйте другое слово — искать можно по-чешски, по-русски и по-украински")
            )
            .padding(.top, AppSpacing.section)
        } else {
            ForEach(viewModel.results) { word in
                NavigationLink(value: word) {
                    WordRow(word: word, language: settings.translationLanguage)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Разделы

    @ViewBuilder
    private func sectionList(_ viewModel: CatalogViewModel) -> some View {
        ForEach(viewModel.sections) { section in
            NavigationLink(value: section) {
                CatalogSectionRow(section: section)
            }
            .buttonStyle(.plain)
        }
    }

    private func load() {
        guard viewModel == nil else { return }
        let model = CatalogViewModel(repository: WordRepository(context: modelContext))
        try? model.load()
        viewModel = model
    }
}

// MARK: - Фильтр уровня

struct LevelSegmentedControl: View {

    @Binding var selection: CEFRLevel?

    var body: some View {
        Picker(selection: $selection) {
            Text("Все").tag(CEFRLevel?.none)
            ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                Text(verbatim: level.rawValue).tag(CEFRLevel?.some(level))
            }
        } label: {
            Text("Уровень")
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(Text("Фильтр по уровню"))
    }
}

// MARK: - Строки

struct CatalogSectionRow: View {

    let section: CatalogViewModel.Section

    var body: some View {
        HStack(spacing: AppSpacing.stack) {
            Image(systemName: section.symbolName)
                .appFont(AppFont.footnote)
                .foregroundStyle(iconTint)
                .frame(width: AppSize.rowIcon, height: AppSize.rowIcon)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: section.title)
                    .appFont(AppFont.callout)
                    .foregroundStyle(AppColor.label)

                DeckProgressBar(share: section.share)
                    .frame(maxWidth: Metrics.progressBarWidth)
            }

            Spacer(minLength: 0)

            Text("\(section.learned) / \(section.total)")
                .appFont(AppFont.callout)
                .foregroundStyle(AppColor.labelSecondary)
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .appFont(AppFont.footnote)
                .foregroundStyle(AppColor.chevron)
        }
        .padding(.horizontal, AppSpacing.rowInset)
        .padding(.vertical, AppSpacing.tight)
        .frame(minHeight: AppSize.listRow)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: section.title))
        .accessibilityValue(Text("Выучено \(section.learned) из \(section.total)"))
    }

    private var iconTint: Color {
        switch section.kind {
        case .phrases: AppColor.indigo
        case .falseFriends: AppColor.warning
        case .category: AppColor.accent
        }
    }

    private var iconBackground: Color {
        switch section.kind {
        case .phrases: AppColor.indigoTint
        case .falseFriends: AppColor.warningTint
        case .category: AppColor.fillSecondary
        }
    }

    private enum Metrics {
        /// Полоса освоения не растягивается на всю строку — справа стоит счётчик.
        static let progressBarWidth: CGFloat = 120
    }
}

struct WordRow: View {

    let word: Word
    let language: TranslationLanguage

    var body: some View {
        HStack(spacing: AppSpacing.stack) {
            VStack(alignment: .leading, spacing: 2) {
                Text.czech(word.czech)
                    .appFont(AppFont.callout)
                    .foregroundStyle(AppColor.label)

                Text(verbatim: word.translation(for: language))
                    .appFont(AppFont.footnote)
                    .foregroundStyle(AppColor.labelSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            StatusDot(progress: word.progress)

            Text(verbatim: word.level.rawValue)
                .appFont(AppFont.caption)
                .foregroundStyle(AppColor.labelTertiary)

            Image(systemName: "chevron.right")
                .appFont(AppFont.footnote)
                .foregroundStyle(AppColor.chevron)
        }
        .padding(.horizontal, AppSpacing.rowInset)
        .padding(.vertical, AppSpacing.tight)
        .frame(minHeight: AppSize.listRow)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }
}

/// Точка статуса: выучено — зелёная, в изучении — оранжевая, новое — без точки.
struct StatusDot: View {

    let progress: WordProgress?

    var body: some View {
        Group {
            if let progress, progress.isLearned {
                dot(AppColor.success)
            } else if let progress, progress.isInProgress {
                dot(AppColor.warning)
            } else {
                Color.clear.frame(width: Metrics.size, height: Metrics.size)
            }
        }
        .accessibilityLabel(Text(statusTitle))
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: Metrics.size, height: Metrics.size)
    }

    private var statusTitle: String {
        guard let progress else { return String(localized: "Не начато") }
        if progress.isLearned { return String(localized: "Выучено") }
        if progress.isInProgress { return String(localized: "В изучении") }
        return String(localized: "Не начато")
    }

    private enum Metrics {
        static let size: CGFloat = 8
    }
}

// MARK: - Список слов раздела

struct WordListView: View {

    let title: String
    let words: [Word]

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.tight) {
                ForEach(words) { word in
                    NavigationLink(value: word) {
                        WordRow(word: word, language: settings.translationLanguage)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.screenInset)
            .padding(.vertical, AppSpacing.stack)
        }
        .background(AppColor.background)
        .navigationTitle(Text(verbatim: title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Пустое состояние

struct EmptyStateView: View {

    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            Image(systemName: symbolName)
                .font(.system(size: Metrics.glyphSize))
                .foregroundStyle(AppColor.success)
                .frame(width: Metrics.circle, height: Metrics.circle)
                .background(AppColor.successTint, in: Circle())

            Text(verbatim: title)
                .appFont(AppFont.headline)
                .foregroundStyle(AppColor.label)

            Text(verbatim: message)
                .appFont(AppFont.subheadline)
                .foregroundStyle(AppColor.labelTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.cardPadding)
    }

    private enum Metrics {
        static let glyphSize: CGFloat = 28
        static let circle: CGFloat = 64
    }
}
