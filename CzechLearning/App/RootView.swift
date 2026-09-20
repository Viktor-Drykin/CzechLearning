//
//  RootView.swift
//  CzechVocab / App
//
//  Корневая навигация: три вкладки поверх экрана импорта.
//

import SwiftData
import SwiftUI

struct RootView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var bootstrap: VocabularyBootstrap?

    var body: some View {
        Group {
            switch bootstrap?.phase {
            case .ready:
                MainTabView()
            case .failed(let message):
                ImportFailureView(message: message) {
                    Task { await bootstrap?.retry() }
                }
            case .importing(let progress):
                ImportProgressView(progress: progress)
            case .idle, .none:
                ImportProgressView(progress: 0)
            }
        }
        .background(AppColor.background)
        .task {
            if bootstrap == nil {
                bootstrap = VocabularyBootstrap(container: modelContext.container)
            }
            await bootstrap?.start()
        }
    }
}

// MARK: - Вкладки

struct MainTabView: View {

    var body: some View {
        TabView {
            Tab(String(localized: "Учить"), systemImage: "rectangle.on.rectangle.angled") {
                PlaceholderTab(title: String(localized: "Учить"))
            }
            Tab(String(localized: "Словарь"), systemImage: "text.book.closed") {
                PlaceholderTab(title: String(localized: "Словарь"))
            }
            Tab(String(localized: "Прогресс"), systemImage: "chart.bar") {
                PlaceholderTab(title: String(localized: "Прогресс"))
            }
        }
        .tint(AppColor.accent)
    }
}

/// Временное содержимое вкладки — заменяется на этапах 3, 4 и 7.
private struct PlaceholderTab: View {

    let title: String

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                Text(title)
                    .appFont(AppFont.title3)
                    .foregroundStyle(AppColor.labelTertiary)
            }
            .navigationTitle(title)
        }
    }
}

// MARK: - Импорт

struct ImportProgressView: View {

    let progress: Double

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: AppSpacing.stack) {
                ProgressView(value: progress)
                    .tint(AppColor.accent)
                    .frame(maxWidth: .infinity)

                Text("Готовим словарь")
                    .appFont(AppFont.headline)
                    .foregroundStyle(AppColor.label)

                Text("Это занимает пару секунд и происходит только один раз")
                    .appFont(AppFont.footnote)
                    .foregroundStyle(AppColor.labelTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppSpacing.cardPadding)
            .padding(.horizontal, AppSpacing.screenInset)
        }
    }
}

struct ImportFailureView: View {

    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: AppSpacing.stack) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(AppColor.danger)

                Text("Не удалось загрузить словарь")
                    .appFont(AppFont.headline)
                    .foregroundStyle(AppColor.label)

                Text(verbatim: message)
                    .appFont(AppFont.footnote)
                    .foregroundStyle(AppColor.labelTertiary)
                    .multilineTextAlignment(.center)

                Button(action: retry) {
                    Text("Повторить")
                        .appFont(AppFont.headline)
                        .foregroundStyle(AppColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.buttonPrimary)
                        .background(
                            AppColor.accent,
                            in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        )
                }
                .padding(.top, AppSpacing.tight)
            }
            .padding(AppSpacing.cardPadding)
            .padding(.horizontal, AppSpacing.screenInset)
        }
    }
}
