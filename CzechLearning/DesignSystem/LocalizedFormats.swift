//
//  LocalizedFormats.swift
//  CzechVocab / DesignSystem
//
//  Строки с двумя и более подстановками.
//
//  Почему не обычная интерполяция в `Text("\(a) из \(b)")`: извлекатель строк
//  кладёт в каталог позиционный ключ `%1$lld из %2$lld`, а `LocalizedStringKey`
//  ищет в рантайме непозиционный `%lld из %lld`. Ключи не совпадают, перевод
//  не находится, и на экране остаётся исходная русская строка.
//  Поэтому позиционный ключ запрашивается явно, а подстановка делается
//  через `String(format:)`.
//

import Foundation

enum LocalizedFormat {

    /// «12 из 694» — выучено из общего числа.
    static func learnedOfTotal(_ learned: Int, of total: Int) -> String {
        String(
            format: String(localized: "%1$lld из %2$lld", comment: "Выучено N из M слов"),
            learned,
            total
        )
    }

    /// «12 / 694» — компактный счётчик в строке списка.
    static func counter(_ value: Int, of total: Int) -> String {
        String(
            format: String(localized: "%1$lld / %2$lld", comment: "Счётчик «N из M»"),
            value,
            total
        )
    }

    /// «Выучено 12 из 694» — значение для VoiceOver.
    static func learnedAccessibilityValue(_ learned: Int, of total: Int) -> String {
        String(
            format: String(localized: "Выучено %1$lld из %2$lld", comment: "VoiceOver: прогресс колоды"),
            learned,
            total
        )
    }

    /// «3 повторить», «10 новых» — разбивка очереди в шапке сессии.
    static func countedLabel(_ count: Int, _ title: String) -> String {
        String(
            format: String(localized: "%1$lld %2$@", comment: "Число и подпись: «10 новых»"),
            count,
            title
        )
    }

    /// «1 ч 05 мин» — длительность сессии.
    static func duration(hours: Int, minutes: Int) -> String {
        String(
            format: String(localized: "%1$lld ч %2$lld мин", comment: "Длительность сессии с часами"),
            hours,
            minutes
        )
    }
}
