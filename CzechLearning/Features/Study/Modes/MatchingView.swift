//
//  MatchingView.swift
//  CzechVocab / Features / Study / Modes
//
//  «Пары»: пять чешских слов слева, переводы вперемешку справа.
//  Верная пара исчезает, неверная подсвечивается красным и разъединяется.
//

import SwiftUI

struct MatchingView: View {

    let words: [MatchingWord]
    let language: TranslationLanguage
    /// Оценка по каждому слову: `good` за верную пару, `hard` за промах.
    let onPair: (Int, ReviewGrade) -> Void
    let onFinished: () -> Void

    @State private var round = MatchingRoundBuilder.Round(wordIDs: [], czechTiles: [], translationTiles: [])
    @State private var selected: MatchingRoundBuilder.Tile?
    @State private var matched: Set<Int> = []
    @State private var wrongPair: Set<String> = []
    @State private var startedAt = Date.now
    /// Время фиксируется, когда раунд собран, — иначе таймер продолжал бы идти.
    @State private var finishedAt: Date?

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            header

            HStack(alignment: .top, spacing: AppSpacing.tight) {
                column(round.czechTiles, isCzech: true)
                column(round.translationTiles, isCzech: false)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            if isRoundComplete {
                PrimaryButton(title: String(localized: "Дальше")) { onFinished() }
            }
        }
        .task(id: words.map(\.id)) { buildRound() }
    }

    // MARK: - Шапка раунда

    private var header: some View {
        HStack {
            Text("Соберите пары")
                .appFont(AppFont.footnote)
                .foregroundStyle(AppColor.labelTertiary)

            Spacer(minLength: 0)

            // TimelineView тикает сам, без таймера в состоянии вьюхи.
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Label {
                    Text(verbatim: timeText(now: finishedAt ?? context.date))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "timer")
                }
                .appFont(AppFont.footnote)
                .foregroundStyle(AppColor.labelSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func timeText(now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Колонки

    private func column(_ tiles: [MatchingRoundBuilder.Tile], isCzech: Bool) -> some View {
        VStack(spacing: AppSpacing.tight) {
            ForEach(tiles) { tile in
                if !matched.contains(tile.wordID) {
                    MatchTile(
                        text: tile.text,
                        isCzech: isCzech,
                        isSelected: selected?.id == tile.id,
                        isWrong: wrongPair.contains(tile.id),
                        action: { tap(tile) }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Логика

    private var isRoundComplete: Bool {
        !round.isEmpty && matched.count == round.wordIDs.count
    }

    private func buildRound() {
        round = MatchingRoundBuilder.build(from: words, language: language)
        selected = nil
        matched = []
        wrongPair = []
        startedAt = .now
        finishedAt = nil
    }

    private func tap(_ tile: MatchingRoundBuilder.Tile) {
        guard !matched.contains(tile.wordID) else { return }

        guard let first = selected else {
            selected = tile
            return
        }
        guard first.id != tile.id else {
            selected = nil
            return
        }
        // Тап по той же колонке — просто переносим выделение.
        guard first.side != tile.side else {
            selected = tile
            return
        }

        if MatchingRoundBuilder.isMatch(first, tile) {
            withAnimation(.easeOut(duration: 0.25)) {
                _ = matched.insert(tile.wordID)
            }
            selected = nil
            onPair(tile.wordID, .good)
            if matched.count == round.wordIDs.count {
                finishedAt = .now
            }
        } else {
            let pair: Set<String> = [first.id, tile.id]
            wrongPair = pair
            selected = nil
            // Промах засчитывается тому слову, которое пользователь выбрал первым.
            onPair(first.wordID, .hard)

            Task {
                try? await Task.sleep(for: .milliseconds(450))
                if wrongPair == pair {
                    wrongPair = []
                }
            }
        }
    }
}

// MARK: - Плитка

struct MatchTile: View {

    let text: String
    let isCzech: Bool
    let isSelected: Bool
    let isWrong: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isCzech {
                    Text.czech(text)
                } else {
                    Text(verbatim: text)
                }
            }
            .appFont(AppFont.body)
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, AppSpacing.tight)
            .frame(maxWidth: .infinity, minHeight: AppSize.matchTile)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        if isWrong { return AppColor.grade(.again).label }
        return isSelected ? AppColor.onAccent : AppColor.label
    }

    private var background: Color {
        if isWrong { return AppColor.grade(.again).background }
        return isSelected ? AppColor.purple : AppColor.surface
    }

    private var border: Color {
        isWrong ? AppColor.danger : .clear
    }
}
