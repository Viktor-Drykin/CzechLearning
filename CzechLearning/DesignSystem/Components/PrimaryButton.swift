//
//  PrimaryButton.swift
//  CzechVocab / DesignSystem / Components
//
//  Кнопки экрана: главная на карточке «Сегодня» (50), кнопка сессии (54)
//  и вторичная на фоне `fill`.
//

import SwiftUI

struct PrimaryButton: View {

    enum Size {
        case primary
        case session

        var height: CGFloat {
            switch self {
            case .primary: AppSize.buttonPrimary
            case .session: AppSize.buttonSession
            }
        }
    }

    let title: String
    var size: Size = .session
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.tight) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(verbatim: title)
            }
            .appFont(AppFont.headline)
            .foregroundStyle(AppColor.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .background(
                isEnabled ? AppColor.accent : AppColor.fill,
                in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct SecondaryButton: View {

    let title: String
    var systemImage: String?
    var tint: Color = AppColor.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.tight) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(verbatim: title)
            }
            .appFont(AppFont.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: AppSize.buttonSession)
            .background(
                AppColor.fill,
                in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Круглая кнопка-иконка

/// Кнопка закрытия сессии и прочие круглые иконки без подписи.
struct CircleIconButton: View {

    let systemImage: String
    let accessibilityTitle: String
    var diameter: CGFloat = AppSize.closeButton
    var foreground: Color = AppColor.labelSecondary
    var background: Color = AppColor.fill
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .appFont(AppFont.headline)
                .foregroundStyle(foreground)
                .frame(width: diameter, height: diameter)
                .background(background, in: Circle())
        }
        .buttonStyle(.plain)
        .minimumTouchTarget()
        .accessibilityLabel(Text(verbatim: accessibilityTitle))
    }
}
