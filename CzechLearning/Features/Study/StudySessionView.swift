//
//  StudySessionView.swift
//  CzechVocab / Features / Study
//
//  Оболочка сессии: шапка с прогрессом, контент режима, подтверждение выхода,
//  экран итогов.
//

import SwiftData
import SwiftUI

struct StudySessionView: View {

    let mode: StudyMode
    let deck: DeckFilter
    var aheadOfSchedule = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(SpeechService.self) private var speech

    @State private var viewModel: StudySessionViewModel?
    @State private var showsCloseConfirmation = false
    @State private var loadFailure: String?

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if let viewModel {
                if viewModel.isFinished {
                    SessionSummaryView(
                        summary: viewModel.summary,
                        onRepeat: { restart() },
                        onDone: { dismiss() }
                    )
                } else {
                    session(viewModel)
                }
            } else if let loadFailure {
                ImportFailureView(message: loadFailure) { restart() }
            } else {
                ProgressView().tint(AppColor.accent)
            }
        }
        .task { start() }
        .confirmationDialog(
            Text("Закончить сессию?"),
            isPresented: $showsCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Закончить"), role: .destructive) { dismiss() }
            Button(String(localized: "Продолжить"), role: .cancel) {}
        } message: {
            Text("Пройдено меньше половины карточек. Ответы уже сохранены.")
        }
        .onDisappear { speech.stop() }
    }

    // MARK: - Сессия

    @ViewBuilder
    private func session(_ viewModel: StudySessionViewModel) -> some View {
        VStack(spacing: AppSpacing.stack) {
            SessionHeader(
                progress: viewModel.progressValue,
                remaining: viewModel.remainingCount,
                reviewCount: viewModel.initialReviewCount,
                newCount: viewModel.initialNewCount,
                learningCount: viewModel.initialLearningCount,
                onClose: { close(viewModel) }
            )

            if let word = viewModel.currentWord {
                modeContent(for: word, viewModel: viewModel)
                    .id(word.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                EmptyQueueView(deck: deck) { dismiss() }
            }
        }
        .padding(.horizontal, AppSpacing.screenInset)
        .padding(.bottom, AppSpacing.safeBottom)
        .animation(.easeInOut(duration: 0.22), value: viewModel.currentIndex)
    }

    @ViewBuilder
    private func modeContent(
        for word: Word,
        viewModel: StudySessionViewModel
    ) -> some View {
        switch mode {
        case .flashcards:
            FlashcardView(
                word: word,
                direction: viewModel.currentDirection,
                language: settings.translationLanguage,
                showImages: settings.showImages,
                clozeEnabled: settings.clozeEnabled,
                intervals: viewModel.intervalLabels(),
                onGrade: { viewModel.submit(grade: $0) }
            )
        case .multipleChoice, .typing, .listening, .matching:
            // Реализуются на этапе 6; до тех пор режим недоступен в выборе.
            FlashcardView(
                word: word,
                direction: viewModel.currentDirection,
                language: settings.translationLanguage,
                showImages: settings.showImages,
                clozeEnabled: settings.clozeEnabled,
                intervals: viewModel.intervalLabels(),
                onGrade: { viewModel.submit(grade: $0) }
            )
        }
    }

    // MARK: - Жизненный цикл

    private func start() {
        guard viewModel == nil else { return }
        let model = StudySessionViewModel(
            mode: mode,
            deck: deck,
            repository: WordRepository(context: modelContext),
            statsRepository: StatsRepository(context: modelContext),
            settings: settings
        )
        do {
            try model.loadQueue(aheadOfSchedule: aheadOfSchedule)
            viewModel = model
            prefetchImages(for: model)
        } catch {
            loadFailure = error.localizedDescription
        }
    }

    private func restart() {
        viewModel = nil
        loadFailure = nil
        start()
    }

    private func close(_ viewModel: StudySessionViewModel) {
        if viewModel.needsCloseConfirmation {
            showsCloseConfirmation = true
        } else {
            dismiss()
        }
    }

    /// Первые карточки очереди подгружаются в фоне, пока пользователь смотрит первую.
    private func prefetchImages(for viewModel: StudySessionViewModel) {
        guard settings.showImages else { return }
        let items = viewModel.queue.compactMap { word -> (id: Int, url: URL)? in
            guard let url = word.imageURL else { return nil }
            return (word.id, url)
        }
        guard !items.isEmpty else { return }
        Task.detached(priority: .utility) {
            await ImageCacheService.shared.prefetch(items)
        }
    }
}

// MARK: - Шапка

struct SessionHeader: View {

    let progress: Double
    let remaining: Int
    let reviewCount: Int
    let newCount: Int
    let learningCount: Int
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.tight) {
            HStack(spacing: AppSpacing.stack) {
                CircleIconButton(
                    systemImage: "xmark",
                    accessibilityTitle: String(localized: "Закрыть сессию"),
                    action: onClose
                )

                SessionProgressBar(value: progress)

                Text("\(remaining)")
                    .appFont(AppFont.footnote)
                    .foregroundStyle(AppColor.labelTertiary)
                    .accessibilityLabel(Text("Осталось карточек: \(remaining)"))
            }

            HStack(spacing: AppSpacing.stack) {
                QueueBreakdownLabel(count: reviewCount, title: String(localized: "повторить"), color: AppColor.accent)
                QueueBreakdownLabel(count: newCount, title: String(localized: "новых"), color: AppColor.success)
                QueueBreakdownLabel(count: learningCount, title: String(localized: "в изучении"), color: AppColor.warning)
                Spacer(minLength: 0)
            }
        }
        .padding(.top, AppSpacing.tight)
    }
}

private struct QueueBreakdownLabel: View {

    let count: Int
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: Metrics.dotSize, height: Metrics.dotSize)
            Text("\(count) \(title)")
                .appFont(AppFont.caption)
                .foregroundStyle(AppColor.labelTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private enum Metrics {
        static let dotSize: CGFloat = 6
    }
}

// MARK: - Пустая очередь

struct EmptyQueueView: View {

    let deck: DeckFilter
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Metrics.glyphSize))
                .foregroundStyle(AppColor.success)

            Text("На сегодня всё")
                .appFont(AppFont.title2)
                .foregroundStyle(AppColor.label)

            Text("В этой колоде не осталось карточек к повторению")
                .appFont(AppFont.subheadline)
                .foregroundStyle(AppColor.labelTertiary)
                .multilineTextAlignment(.center)

            Spacer()

            PrimaryButton(title: String(localized: "Готово"), action: onDone)
        }
    }

    private enum Metrics {
        static let glyphSize: CGFloat = 48
    }
}
