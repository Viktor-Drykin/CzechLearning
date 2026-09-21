//
//  SessionSummaryView.swift
//  CzechVocab / Features / Study
//
//  Итоги сессии: карточек, процент верных, новых выучено, время.
//

import SwiftUI

struct SessionSummaryView: View {

    let summary: StudySessionViewModel.Summary
    let onRepeat: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()

            VStack(spacing: AppSpacing.tight) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: Metrics.glyphSize))
                    .foregroundStyle(AppColor.success)

                Text("Сессия завершена")
                    .appFont(AppFont.title2)
                    .foregroundStyle(AppColor.label)
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.stack) {
                StatTile(
                    value: "\(summary.answered)",
                    title: String(localized: "карточек")
                )
                StatTile(
                    value: summary.accuracy.formatted(.percent.precision(.fractionLength(0))),
                    title: String(localized: "верных"),
                    tint: AppColor.progress(share: summary.accuracy)
                )
                StatTile(
                    value: "\(summary.newLearned)",
                    title: String(localized: "новых выучено"),
                    tint: AppColor.success
                )
                StatTile(
                    value: Self.durationText(summary.duration),
                    title: String(localized: "времени")
                )
            }

            Spacer()

            VStack(spacing: AppSpacing.tight) {
                PrimaryButton(title: String(localized: "Ещё раз"), action: onRepeat)
                SecondaryButton(title: String(localized: "Готово"), action: onDone)
            }
        }
        .padding(.horizontal, AppSpacing.screenInset)
        .padding(.bottom, AppSpacing.safeBottom)
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: AppSpacing.stack),
            GridItem(.flexible(), spacing: AppSpacing.stack),
        ]
    }

    /// «4 мин», «1 ч 05 мин» — время сессии, а не интервал повторения.
    static func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        guard totalMinutes >= 60 else {
            return String(localized: "\(max(1, totalMinutes)) мин", comment: "Длительность сессии")
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(localized: "\(hours) ч \(minutes) мин", comment: "Длительность сессии с часами")
    }

    private enum Metrics {
        static let glyphSize: CGFloat = 48
    }
}

// MARK: - Плитка

struct StatTile: View {

    let value: String
    let title: String
    var tint: Color = AppColor.label
    var symbolName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let symbolName {
                Image(systemName: symbolName)
                    .appFont(AppFont.footnote)
                    .foregroundStyle(tint)
            }

            Text(verbatim: value)
                .appFont(AppFont.statNumberSmall)
                .foregroundStyle(tint)

            Text(verbatim: title)
                .appFont(AppFont.footnote)
                .foregroundStyle(AppColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPaddingCompact)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: value))
    }
}
