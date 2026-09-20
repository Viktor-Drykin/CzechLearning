//
//  IntervalFormatter.swift
//  CzechVocab / Domain / SRS
//
//  Подписи интервалов над кнопками оценки. Считает домен, а не вьюха
//  (требование DesignSystem.md, раздел 4).
//

import Foundation

nonisolated enum IntervalFormatter {

    /// Короткая подпись для кнопки оценки: «1 мин», «10 мин», «1 д», «4 д», «2 мес».
    static func shortLabel(for interval: TimeInterval) -> String {
        let seconds = max(0, interval)

        if seconds < 60 {
            return String(localized: "<1 мин", comment: "Интервал меньше минуты")
        }
        if seconds < 3600 {
            let minutes = Int((seconds / 60).rounded())
            return String(localized: "\(minutes) мин", comment: "Интервал в минутах")
        }
        if seconds < SRSConstants.secondsPerDay {
            let hours = Int((seconds / 3600).rounded())
            return String(localized: "\(hours) ч", comment: "Интервал в часах")
        }

        let days = seconds / SRSConstants.secondsPerDay
        if days < 30 {
            return String(localized: "\(Int(days.rounded())) д", comment: "Интервал в днях")
        }
        if days < 365 {
            let months = Int((days / 30).rounded())
            return String(localized: "\(months) мес", comment: "Интервал в месяцах")
        }

        let years = (days / 365 * 10).rounded() / 10
        return years == years.rounded()
            ? String(localized: "\(Int(years)) г", comment: "Интервал в годах")
            : String(localized: "\(years, format: .number.precision(.fractionLength(1))) г", comment: "Интервал в годах с долей")
    }

    /// Подписи всех четырёх кнопок для текущего состояния карточки.
    static func previewLabels(for state: SRSState, now: Date = .now) -> [ReviewGrade: String] {
        SRSScheduler.previews(for: state, now: now).mapValues(shortLabel(for:))
    }
}
