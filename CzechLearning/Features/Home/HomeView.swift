//
//  HomeView.swift
//  CzechVocab / Features / Home
//
//  Вкладка «Учить»: карточка «Сегодня», колоды по уровням, трудные слова.
//

import SwiftData
import SwiftUI

struct HomeView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings

    @State private var viewModel: HomeViewModel?
    @State private var session: SessionRequest?

    /// Что именно запускаем: режим, колода и «вперёд ли».
    struct SessionRequest: Identifiable {
        let mode: StudyMode
        let deck: DeckFilter
        let aheadOfSchedule: Bool

        var id: String {
            "\(mode.rawValue)-\(deck.levels.map(\.rawValue).sorted().joined())-\(deck.onlyDifficult)-\(aheadOfSchedule)"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    if let viewModel {
                        todayCard(viewModel)
                        deckSection(viewModel)
                        difficultButton(viewModel)
                    } else {
                        ProgressView().tint(AppColor.accent)
                    }
                }
                .padding(.horizontal, AppSpacing.screenInset)
                .padding(.vertical, AppSpacing.stack)
            }
            .background(AppColor.background)
            .navigationTitle(Text("Учить"))
            .toolbarTitleDisplayMode(.inlineLarge)
        }
        .task { refresh() }
        .fullScreenCover(item: $session, onDismiss: { refresh() }) { request in
            StudySessionView(
                mode: request.mode,
                deck: request.deck,
                aheadOfSchedule: request.aheadOfSchedule
            )
        }
    }

    // MARK: - Сегодня

    @ViewBuilder
    private func todayCard(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.stack) {
            Text("Сегодня")
                .appFont(AppFont.sectionHeader)
                .textCase(.uppercase)
                .foregroundStyle(AppColor.labelTertiary)

            if viewModel.hasWorkToday {
                HStack(spacing: AppSpacing.section) {
                    CountColumn(
                        value: viewModel.dueCount,
                        title: String(localized: "к повторению"),
                        tint: AppColor.accent
                    )
                    CountColumn(
                        value: viewModel.newCount,
                        title: String(localized: "новых"),
                        tint: AppColor.success
                    )
                    Spacer(minLength: 0)
                }

                PrimaryButton(
                    title: String(localized: "Начать"),
                    size: .primary
                ) {
                    session = SessionRequest(
                        mode: settings.defaultMode,
                        deck: .all,
                        aheadOfSchedule: false
                    )
                }
            } else {
                emptyToday(viewModel)
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.surface,
            in: RoundedRectangle(cornerRadius: AppRadius.cardLarge, style: .continuous)
        )
    }

    @ViewBuilder
    private func emptyToday(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.stack) {
            HStack(spacing: AppSpacing.tight) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColor.success)
                    .frame(width: AppSize.rowIcon, height: AppSize.rowIcon)
                    .background(AppColor.successTint, in: RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous))

                Text("На сегодня всё")
                    .appFont(AppFont.headline)
                    .foregroundStyle(AppColor.label)
            }

            Text("Повторений на сегодня нет. Можно взять новые слова вперёд.")
                .appFont(AppFont.subheadline)
                .foregroundStyle(AppColor.labelTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.hasUnseenWords {
                PrimaryButton(
                    title: String(localized: "Учить вперёд"),
                    size: .primary
                ) {
                    session = SessionRequest(
                        mode: settings.defaultMode,
                        deck: .all,
                        aheadOfSchedule: true
                    )
                }
            }
        }
    }

    // MARK: - Колоды

    @ViewBuilder
    private func deckSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.stack) {
            Text("Колоды")
                .appFont(AppFont.sectionHeader)
                .textCase(.uppercase)
                .foregroundStyle(AppColor.labelTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.stack) {
                    ForEach(viewModel.decks) { deck in
                        DeckCard(deck: deck) {
                            session = SessionRequest(
                                mode: settings.defaultMode,
                                deck: .level(deck.level),
                                aheadOfSchedule: false
                            )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenInset)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -AppSpacing.screenInset)
        }
    }

    // MARK: - Трудные слова

    @ViewBuilder
    private func difficultButton(_ viewModel: HomeViewModel) -> some View {
        if viewModel.difficultCount > 0 {
            Button {
                session = SessionRequest(mode: settings.defaultMode, deck: .difficult, aheadOfSchedule: false)
            } label: {
                HStack(spacing: AppSpacing.stack) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(AppColor.danger)
                        .frame(width: AppSize.rowIcon, height: AppSize.rowIcon)
                        .background(
                            AppColor.dangerTint,
                            in: RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                        )

                    Text("Трудные слова")
                        .appFont(AppFont.callout)
                        .foregroundStyle(AppColor.label)

                    Spacer(minLength: 0)

                    Text("\(viewModel.difficultCount)")
                        .appFont(AppFont.callout)
                        .foregroundStyle(AppColor.labelSecondary)

                    Image(systemName: "chevron.right")
                        .appFont(AppFont.footnote)
                        .foregroundStyle(AppColor.chevron)
                }
                .padding(.horizontal, AppSpacing.rowInset)
                .frame(height: AppSize.listRow)
                .cardSurface()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Загрузка

    private func refresh() {
        let model = viewModel ?? HomeViewModel(
            repository: WordRepository(context: modelContext),
            statsRepository: StatsRepository(context: modelContext),
            settings: settings
        )
        try? model.refresh()
        viewModel = model
    }
}

// MARK: - Составные части

private struct CountColumn: View {

    let value: Int
    let title: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .appFont(AppFont.statNumber)
                .foregroundStyle(tint)
            Text(verbatim: title)
                .appFont(AppFont.footnote)
                .foregroundStyle(AppColor.labelSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text("\(value)"))
    }
}

private struct DeckCard: View {

    let deck: HomeViewModel.DeckSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                Text(verbatim: deck.level.rawValue)
                    .appFont(AppFont.title3)
                    .foregroundStyle(AppColor.label)

                Text("\(deck.learned) из \(deck.total)")
                    .appFont(AppFont.footnote)
                    .foregroundStyle(AppColor.labelSecondary)

                DeckProgressBar(share: deck.share)
            }
            .padding(AppSpacing.cardPaddingCompact)
            .frame(width: Metrics.width, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Колода \(deck.level.rawValue)"))
        .accessibilityValue(Text("Выучено \(deck.learned) из \(deck.total)"))
    }

    private enum Metrics {
        static let width: CGFloat = 140
    }
}
