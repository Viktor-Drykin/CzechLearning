//
//  ImagePlaceholder.swift
//  CzechVocab / DesignSystem / Components
//
//  Плейсхолдер картинки: фон `fillSecondary`, глиф по части речи, подпись
//  цветом `labelQuaternary`. Показывается всегда, когда картинки нет или
//  загрузка не удалась — карточка при этом не меняет размеров.
//

import SwiftUI

struct ImagePlaceholder: View {

    let symbolName: String
    var height: CGFloat = Metrics.defaultHeight

    var body: some View {
        RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            .fill(AppColor.fillSecondary)
            .frame(height: height)
            .overlay {
                VStack(spacing: AppSpacing.tight) {
                    Image(systemName: symbolName)
                        .font(.system(size: Metrics.glyphSize))
                    Text("картинка слова")
                        .appFont(AppFont.caption)
                }
                .foregroundStyle(AppColor.labelQuaternary)
            }
            .accessibilityHidden(true)
    }

    enum Metrics {
        static let defaultHeight: CGFloat = 160
        static let compactHeight: CGFloat = 120
        static let glyphSize: CGFloat = 36
    }
}

#Preview {
    VStack(spacing: AppSpacing.stack) {
        ImagePlaceholder(symbolName: PartOfSpeech.noun.placeholderSymbol)
        ImagePlaceholder(
            symbolName: PartOfSpeech.phrase.placeholderSymbol,
            height: ImagePlaceholder.Metrics.compactHeight
        )
    }
    .padding(AppSpacing.screenInset)
    .background(AppColor.background)
}
