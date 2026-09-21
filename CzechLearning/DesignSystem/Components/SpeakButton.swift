//
//  SpeakButton.swift
//  CzechVocab / DesignSystem / Components
//
//  Круглая кнопка озвучки: 40 pt, фон `accentTint`, глиф `accent`.
//  Скрывается целиком, если чешский голос не установлен.
//

import SwiftUI

struct SpeakButton: View {

    enum Style {
        /// Круглая кнопка 40 pt рядом со словом.
        case standard
        /// Компактный глиф в строке примера.
        case compact
    }

    let text: String
    var style: Style = .standard
    var rateMultiplier: Double?

    @Environment(SpeechService.self) private var speech
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        if speech.isCzechVoiceAvailable {
            Button {
                speech.speak(text, rateMultiplier: rateMultiplier ?? settings.speechRateMultiplier)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .appFont(style == .standard ? AppFont.headline : AppFont.footnote)
                    .foregroundStyle(AppColor.accent)
                    .frame(width: diameter, height: diameter)
                    .background(AppColor.accentTint, in: Circle())
            }
            .buttonStyle(.plain)
            .minimumTouchTarget()
            .accessibilityLabel(Text("Прослушать"))
        }
    }

    private var diameter: CGFloat {
        switch style {
        case .standard: AppSize.speakButton
        case .compact: Metrics.compactDiameter
        }
    }

    private enum Metrics {
        static let compactDiameter: CGFloat = 28
    }
}
