//
//  NoteCallout.swift
//  CzechVocab / DesignSystem / Components
//
//  Единственный способ показать `note`: янтарный блок с рамкой.
//  38 записей словаря, в том числе ложные друзья.
//

import SwiftUI

struct NoteCallout: View {

    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.tight) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: Metrics.iconSize))
                .foregroundStyle(AppColor.noteLabel)

            Text(verbatim: text)
                .appFont(AppFont.subheadline)
                .foregroundStyle(AppColor.noteLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.cardPaddingCompact)
        .background(
            AppColor.noteBackground,
            in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .strokeBorder(AppColor.noteBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Примечание"))
        .accessibilityValue(Text(verbatim: text))
    }

    private enum Metrics {
        static let iconSize: CGFloat = 18
    }
}

#Preview {
    NoteCallout(text: "Ложный друг: НЕ «позор»")
        .padding(AppSpacing.screenInset)
        .background(AppColor.background)
}
