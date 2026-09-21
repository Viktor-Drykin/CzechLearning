//
//  StatsView.swift
//  CzechVocab / Features / Stats
//
//  Вкладка «Прогресс»: плитки, график активности за 30 дней,
//  разбивка по уровням и категориям. Настройки — в навбаре.
//

import Charts
import SwiftData
import SwiftUI

struct StatsView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: StatsViewModel?
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    if let viewModel {
                        tiles(viewModel)
                        activityChart(viewModel)
                        breakdown(
                            title: String(localized: "По уровням"),
                            rows: viewModel.levels
                        )
                        breakdown(
                            title: String(localized: "По темам"),
                            rows: viewModel.categories
                        )
                    } else {
                        ProgressView().tint(AppColor.accent)
                    }
                }
                .padding(.horizontal, AppSpacing.screenInset)
                .padding(.vertical, AppSpacing.stack)
            }
            .background(AppColor.background)
            .navigationTitle(Text("Прогресс"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(Text("Настройки"))
                }
            }
            .sheet(isPresented: $showsSettings, onDismiss: { refresh() }) {
                SettingsView()
            }
        }
        .task { refresh() }
    }

    // MARK: - Плитки

    private func tiles(_ viewModel: StatsViewModel) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppSpacing.stack),
                GridItem(.flexible(), spacing: AppSpacing.stack),
            ],
            spacing: AppSpacing.stack
        ) {
            StatTile(
                value: "\(viewModel.learnedCount)",
                title: String(localized: "выучено"),
                tint: AppColor.success,
                symbolName: "checkmark.circle.fill"
            )
            StatTile(
                value: "\(viewModel.inProgressCount)",
                title: String(localized: "в изучении"),
                tint: AppColor.warning,
                symbolName: "clock.fill"
            )
            StatTile(
                value: "\(viewModel.remainingNewCount)",
                title: String(localized: "новых осталось"),
                symbolName: "sparkles"
            )
            StatTile(
                value: viewModel.averageAccuracy.formatted(.percent.precision(.fractionLength(0))),
                title: String(localized: "верных ответов"),
                tint: AppColor.accent,
                symbolName: "target"
            )
        }
    }

    // MARK: - График

    @ViewBuilder
    private func activityChart(_ viewModel: StatsViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.stack) {
            SectionHeader(title: String(localized: "Активность за 30 дней"))

            if viewModel.activityMaximum == 0 {
                Text("Ответов пока нет — график появится после первой сессии")
                    .appFont(AppFont.footnote)
                    .foregroundStyle(AppColor.labelTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.cardPaddingCompact)
                    .cardSurface()
            } else {
                Chart(viewModel.activity) { bar in
                    BarMark(
                        x: .value(String(localized: "День"), bar.day, unit: .day),
                        y: .value(String(localized: "Ответов"), max(bar.answers, 0))
                    )
                    .foregroundStyle(
                        AppColor.Chart.bar(
                            share: viewModel.activityMaximum > 0
                                ? Double(bar.answers) / Double(viewModel.activityMaximum)
                                : 0
                        )
                    )
                    .cornerRadius(Metrics.barRadius)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(AppColor.separator)
                        AxisValueLabel().foregroundStyle(AppColor.labelTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.narrow))
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                }
                .frame(height: Metrics.chartHeight)
                .padding(AppSpacing.cardPaddingCompact)
                .cardSurface()
            }
        }
    }

    // MARK: - Разбивка

    @ViewBuilder
    private func breakdown(title: String, rows: [StatsViewModel.Breakdown]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                SectionHeader(title: title)

                VStack(spacing: AppSpacing.tight) {
                    ForEach(rows) { row in
                        BreakdownRow(row: row)
                    }
                }
            }
        }
    }

    private func refresh() {
        let model = viewModel ?? StatsViewModel(
            repository: WordRepository(context: modelContext),
            statsRepository: StatsRepository(context: modelContext)
        )
        try? model.refresh()
        viewModel = model
    }

    private enum Metrics {
        static let chartHeight: CGFloat = 160
        static let barRadius: CGFloat = 2
    }
}

// MARK: - Строка разбивки

private struct BreakdownRow: View {

    let row: StatsViewModel.Breakdown

    var body: some View {
        HStack(spacing: AppSpacing.stack) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: row.title)
                    .appFont(AppFont.callout)
                    .foregroundStyle(AppColor.label)
                    .lineLimit(1)

                DeckProgressBar(share: row.share)
            }

            Text(verbatim: LocalizedFormat.counter(row.learned, of: row.total))
                .appFont(AppFont.footnote)
                .foregroundStyle(AppColor.labelSecondary)
                .monospacedDigit()
                .frame(minWidth: Metrics.counterWidth, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.rowInset)
        .padding(.vertical, AppSpacing.tight)
        .frame(minHeight: AppSize.listRow)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: row.title))
        .accessibilityValue(Text(verbatim: LocalizedFormat.learnedAccessibilityValue(row.learned, of: row.total)))
    }

    private enum Metrics {
        static let counterWidth: CGFloat = 72
    }
}
