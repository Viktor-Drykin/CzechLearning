//
//  SessionProgressBar.swift
//  CzechVocab / DesignSystem / Components
//
//  Прогресс-бар сессии: высота 6, радиус 3, трек `track`, заливка `accent`.
//

import SwiftUI

struct SessionProgressBar: View {

    /// Доля пройденного, 0…1.
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(AppColor.track)

                Capsule(style: .continuous)
                    .fill(AppColor.accent)
                    .frame(width: geometry.size.width * clamped)
            }
        }
        .frame(height: AppSize.progressBar)
        .accessibilityElement()
        .accessibilityLabel(Text("Прогресс сессии"))
        .accessibilityValue(Text(clamped, format: .percent.precision(.fractionLength(0))))
    }

    private var clamped: Double {
        min(1, max(0, value))
    }
}

// MARK: - Полоса освоения колоды

/// Тонкая полоса под названием колоды или категории.
/// Цвет — по доле выученного, через `AppColor.progress(share:)`.
struct DeckProgressBar: View {

    let share: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(AppColor.track)

                Capsule(style: .continuous)
                    .fill(AppColor.progress(share: share))
                    .frame(width: geometry.size.width * min(1, max(0, share)))
            }
        }
        .frame(height: AppSize.progressBar)
        .accessibilityHidden(true)
    }
}
