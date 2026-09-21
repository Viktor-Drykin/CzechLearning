//
//  WordRepository.swift
//  CzechVocab / Data / Repositories
//
//  Доступ к словам и прогрессу. Вьюхи и вью-модели не трогают ModelContext
//  напрямую: выборки и запись живут здесь.
//

import Foundation
import SwiftData

@MainActor
struct WordRepository {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Выборка

    func word(id: Int) throws -> Word? {
        var descriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func words(ids: [Int]) throws -> [Word] {
        guard !ids.isEmpty else { return [] }
        let wanted = Set(ids)
        let fetched = try context.fetch(
            FetchDescriptor<Word>(predicate: #Predicate { wanted.contains($0.id) })
        )
        // Порядок очереди задаёт QueueBuilder, выборка его не сохраняет.
        let byID = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    func allWords() throws -> [Word] {
        try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.id)]))
    }

    func wordCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<Word>())
    }

    // MARK: - Кандидаты для очереди

    /// Снимки всех слов для `QueueBuilder`. Одна выборка вместо похода за прогрессом
    /// по каждому слову: 1744 записи читаются быстрее, чем 1744 запроса.
    func queueCandidates() throws -> [QueueCandidate] {
        try allWords().map(Self.candidate(for:))
    }

    nonisolated static func candidate(for word: Word) -> QueueCandidate {
        let progress = word.progress
        return QueueCandidate(
            id: word.id,
            level: word.level,
            category: word.category,
            isPhrase: word.isPhrase,
            state: progress?.state ?? .new,
            dueDate: progress?.dueDate,
            lapses: progress?.lapses ?? 0,
            totalReviews: progress?.totalReviews ?? 0,
            correctReviews: progress?.correctReviews ?? 0,
            isSuspended: progress?.isSuspended ?? false
        )
    }

    // MARK: - Прогресс

    /// Возвращает прогресс слова, создавая его при первом показе карточки (ТЗ 5.2, п. 6).
    @discardableResult
    func progress(for word: Word) -> WordProgress {
        if let existing = word.progress { return existing }
        let created = WordProgress(word: word)
        context.insert(created)
        word.progress = created
        return created
    }

    func allProgress() throws -> [WordProgress] {
        try context.fetch(FetchDescriptor<WordProgress>())
    }

    /// Записывает ответ: новое состояние SM-2, счётчики и строку журнала.
    func recordAnswer(
        word: Word,
        grade: ReviewGrade,
        mode: StudyMode,
        responseTime: TimeInterval,
        now: Date = .now
    ) throws {
        let progress = progress(for: word)
        let previous = SRSState(progress: progress)
        let next = SRSScheduler.schedule(progress: previous, grade: grade, now: now)

        next.apply(to: progress)
        progress.totalReviews += 1
        if grade != .again {
            progress.correctReviews += 1
        }
        progress.lastReviewedAt = now

        context.insert(
            ReviewLog(
                wordID: word.id,
                reviewedAt: now,
                gradeRaw: grade.rawValue,
                modeRaw: mode.rawValue,
                responseTimeMS: Int(responseTime * 1000),
                previousIntervalDays: previous.intervalDays,
                newIntervalDays: next.intervalDays
            )
        )
    }

    func setSuspended(_ suspended: Bool, for word: Word) {
        progress(for: word).isSuspended = suspended
    }

    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
