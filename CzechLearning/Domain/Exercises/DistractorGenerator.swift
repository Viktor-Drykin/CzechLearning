//
//  DistractorGenerator.swift
//  CzechVocab / Domain / Exercises
//
//  Три неверных варианта к правильному ответу (ТЗ 7.2).
//
//  Работает со снимками, а не с моделями SwiftData: правила приоритета
//  тестируются на выдуманном словаре без контейнера.
//

import Foundation

// MARK: - Кандидат

/// Снимок слова, достаточный для подбора вариантов ответа.
nonisolated struct DistractorCandidate: Sendable, Equatable, Identifiable {

    let id: Int
    let czech: String
    let level: CEFRLevel
    let category: String
    let isPhrase: Bool
    /// Значения перевода по языкам — первое из них идёт в вариант ответа.
    let russianMeanings: [String]
    let ukrainianMeanings: [String]
    let note: String?

    init(
        id: Int,
        czech: String,
        level: CEFRLevel,
        category: String,
        isPhrase: Bool,
        russianMeanings: [String],
        ukrainianMeanings: [String],
        note: String? = nil
    ) {
        self.id = id
        self.czech = czech
        self.level = level
        self.category = category
        self.isPhrase = isPhrase
        self.russianMeanings = russianMeanings
        self.ukrainianMeanings = ukrainianMeanings
        self.note = note
    }

    func meanings(for language: TranslationLanguage) -> [String] {
        switch language {
        case .russian: russianMeanings
        case .ukrainian: ukrainianMeanings
        }
    }

    func primaryTranslation(for language: TranslationLanguage) -> String {
        meanings(for: language).first ?? ""
    }
}

// MARK: - Генератор

nonisolated struct DistractorGenerator {

    /// Сколько вариантов на экране: один верный и три неверных.
    static let optionCount = 4
    static let distractorCount = optionCount - 1

    /// Маркер правила ложных друзей в колонке `note`.
    static let falseFriendMarker = "Ложный друг"

    /// Подбирает три дистрактора по правилам приоритета.
    /// - Parameter shuffle: перемешивание внутри группы; в тестах — тождественное.
    static func distractors(
        for target: DistractorCandidate,
        in dictionary: [DistractorCandidate],
        language: TranslationLanguage,
        shuffle: ([DistractorCandidate]) -> [DistractorCandidate] = { $0.shuffled() }
    ) -> [DistractorCandidate] {
        var chosen: [DistractorCandidate] = []
        var usedTranslations: Set<String> = [target.primaryTranslation(for: language)]

        func accept(_ candidate: DistractorCandidate) -> Bool {
            guard chosen.count < distractorCount else { return false }
            guard candidate.id != target.id else { return false }
            // Фразу не предлагаем к обычному слову: длина вариантов несопоставима.
            guard target.isPhrase || !candidate.isPhrase else { return false }

            let translation = candidate.primaryTranslation(for: language)
            guard !translation.isEmpty, !usedTranslations.contains(translation) else { return false }

            chosen.append(candidate)
            usedTranslations.insert(translation)
            return true
        }

        // Правило 1: слово, с которым легко спутать целевое.
        if let confusable = falseFriendDistractor(for: target, in: dictionary, language: language) {
            _ = accept(confusable)
        }

        let pool = dictionary.filter { $0.id != target.id }

        // Правило 2: та же тема и тот же уровень.
        for candidate in shuffle(pool.filter {
            $0.category == target.category && $0.level == target.level
        }) where chosen.count < distractorCount {
            _ = accept(candidate)
        }

        // Правило 3: та же тема, любой уровень.
        for candidate in shuffle(pool.filter { $0.category == target.category })
        where chosen.count < distractorCount {
            _ = accept(candidate)
        }

        // Правило 4: тот же уровень, любая тема.
        for candidate in shuffle(pool.filter { $0.level == target.level })
        where chosen.count < distractorCount {
            _ = accept(candidate)
        }

        // Запасной вариант: словарь слишком узкий под фильтры — берём что есть,
        // иначе на экране окажется меньше четырёх кнопок.
        for candidate in shuffle(pool) where chosen.count < distractorCount {
            _ = accept(candidate)
        }

        return chosen
    }

    /// Готовые варианты ответа в перемешанном порядке.
    static func options(
        for target: DistractorCandidate,
        in dictionary: [DistractorCandidate],
        language: TranslationLanguage,
        shuffle: ([DistractorCandidate]) -> [DistractorCandidate] = { $0.shuffled() }
    ) -> [DistractorCandidate] {
        let wrong = distractors(for: target, in: dictionary, language: language, shuffle: shuffle)
        return shuffle([target] + wrong)
    }

    // MARK: - Правило ложных друзей

    /// Ищет слово, которое пользователь мог бы перепутать с целевым.
    ///
    /// Спутываемое слово во всех семи записях стоит в кавычках-ёлочках:
    /// «Ложный друг: НЕ «позор»», «Ложный друг: «час» = hodina». Искать
    /// подстроку по всему примечанию нельзя — слово «друг» из самого маркера
    /// совпало бы с `kamarád` и `přítel` у каждой из семи записей.
    static func falseFriendDistractor(
        for target: DistractorCandidate,
        in dictionary: [DistractorCandidate],
        language: TranslationLanguage
    ) -> DistractorCandidate? {
        guard let note = target.note, note.contains(falseFriendMarker) else { return nil }

        let quoted = quotedFragments(in: note)
        guard !quoted.isEmpty else { return nil }

        for fragment in quoted {
            let needle = fragment.lowercased()
            let match = dictionary.first { candidate in
                guard candidate.id != target.id else { return false }
                return candidate.meanings(for: .russian)
                    .contains { $0.lowercased() == needle }
            }
            if let match, !match.primaryTranslation(for: language).isEmpty {
                return match
            }
        }
        return nil
    }

    /// Фрагменты в кавычках-ёлочках.
    static func quotedFragments(in text: String) -> [String] {
        var result: [String] = []
        var current: String?

        for character in text {
            switch character {
            case "«":
                current = ""
            case "»":
                if let value = current?.trimmingCharacters(in: .whitespaces), !value.isEmpty {
                    result.append(value)
                }
                current = nil
            default:
                current?.append(character)
            }
        }
        return result
    }
}

// MARK: - Мост к моделям

extension DistractorCandidate {

    init(word: Word) {
        self.init(
            id: word.id,
            czech: word.czech,
            level: word.level,
            category: word.category,
            isPhrase: word.isPhrase,
            russianMeanings: word.translationMeanings(for: .russian),
            ukrainianMeanings: word.translationMeanings(for: .ukrainian),
            note: word.noteText
        )
    }
}
