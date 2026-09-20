//
//  ReviewLog.swift
//  CzechVocab / Data / Models
//
//  Журнал ответов. Ссылается на слово по `id`, а не отношением: журнал переживает
//  переимпорт словаря и не должен удерживать граф объектов.
//

import Foundation
import SwiftData

@Model
final class ReviewLog {

    var wordID: Int
    var reviewedAt: Date
    var gradeRaw: Int
    var modeRaw: String
    var responseTimeMS: Int
    var previousIntervalDays: Double
    var newIntervalDays: Double

    init(
        wordID: Int,
        reviewedAt: Date,
        gradeRaw: Int,
        modeRaw: String,
        responseTimeMS: Int,
        previousIntervalDays: Double,
        newIntervalDays: Double
    ) {
        self.wordID = wordID
        self.reviewedAt = reviewedAt
        self.gradeRaw = gradeRaw
        self.modeRaw = modeRaw
        self.responseTimeMS = responseTimeMS
        self.previousIntervalDays = previousIntervalDays
        self.newIntervalDays = newIntervalDays
    }
}

nonisolated extension ReviewLog {

    var grade: ReviewGrade {
        ReviewGrade(rawValue: gradeRaw) ?? .again
    }

    var mode: StudyMode {
        StudyMode(rawValue: modeRaw) ?? .flashcards
    }
}
