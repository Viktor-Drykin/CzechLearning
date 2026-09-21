//
//  GradeButtonRow.swift
//  CzechVocab / DesignSystem / Components
//
//  Четыре кнопки оценки в ряд, равной ширины, gap 8.
//  Сверху — интервал (caption2, моноцифры), снизу — подпись (headline).
//  Интервалы приходят готовыми строками из SRSScheduler; вьюха их не считает.
//

import SwiftUI

struct GradeButtonRow: View {

    /// Подписи интервалов по оценкам. Отсутствующий ключ — пустая строка.
    let intervals: [ReviewGrade: String]
    let action: (ReviewGrade) -> Void

    var body: some View {
        HStack(spacing: AppSpacing.tight) {
            ForEach(ReviewGrade.allCases, id: \.rawValue) { grade in
                GradeButton(
                    grade: grade,
                    interval: intervals[grade] ?? "",
                    action: { action(grade) }
                )
            }
        }
    }
}

struct GradeButton: View {

    let grade: ReviewGrade
    let interval: String
    let action: () -> Void

    var body: some View {
        let palette = AppColor.grade(grade)

        Button(action: action) {
            VStack(spacing: Metrics.labelGap) {
                Text(verbatim: interval)
                    .appFont(AppFont.caption2)
                    .foregroundStyle(palette.interval)

                Text(verbatim: grade.displayName)
                    .appFont(AppFont.headline)
                    .foregroundStyle(palette.label)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppSize.gradeButton)
            .background(
                palette.background,
                in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: grade.displayName))
        .accessibilityValue(Text("Следующий показ через \(interval)"))
    }

    private enum Metrics {
        static let labelGap: CGFloat = 2
    }
}

#Preview {
    VStack {
        GradeButtonRow(
            intervals: [.again: "1 мин", .hard: "1 мин", .good: "10 мин", .easy: "4 д"],
            action: { _ in }
        )
    }
    .padding(AppSpacing.screenInset)
    .background(AppColor.background)
}
