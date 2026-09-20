//
//  DailyStats.swift
//  CzechVocab / Data / Models
//
//  Агрегат за день для графика активности. Ключ — начало дня в часовом поясе
//  пользователя; считается через `Calendar.current`, чтобы «сегодня» на экране
//  совпадало с «сегодня» в базе.
//

import Foundation
import SwiftData

@Model
final class DailyStats {

    @Attribute(.unique) var day: Date
    var newCardsStudied: Int
    var reviewsCompleted: Int
    var correctCount: Int
    var studyTimeSeconds: Int

    init(
        day: Date,
        newCardsStudied: Int = 0,
        reviewsCompleted: Int = 0,
        correctCount: Int = 0,
        studyTimeSeconds: Int = 0
    ) {
        self.day = day
        self.newCardsStudied = newCardsStudied
        self.reviewsCompleted = reviewsCompleted
        self.correctCount = correctCount
        self.studyTimeSeconds = studyTimeSeconds
    }
}

nonisolated extension DailyStats {

    /// Начало дня, пригодное как ключ `day`.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Всего ответов за день — сумма повторений и новых карточек.
    var totalAnswers: Int {
        reviewsCompleted
    }
}
