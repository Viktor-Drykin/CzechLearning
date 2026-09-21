//
//  ImagePlaceholder.swift
//  CzechVocab / DesignSystem / Components
//
//  Плейсхолдер картинки: фон `fillSecondary`, глиф по части речи, подпись
//  цветом `labelQuaternary`. Держит место, пока картинка грузится, и остаётся,
//  если загрузка не удалась, — карточка при этом не меняет размеров.
//  У слов без `imageURL` не показывается вовсе: см. `WordImageView`.
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
                        .appSymbol(AppSymbol.placeholder)
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
