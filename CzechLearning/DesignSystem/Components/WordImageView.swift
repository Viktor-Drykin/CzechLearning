//
//  WordImageView.swift
//  CzechVocab / DesignSystem / Components
//
//  Картинка слова с дисковым кэшем и плейсхолдером. Размер не зависит
//  от того, загрузилась картинка или нет: карточка не должна прыгать.
//

import SwiftUI

struct WordImageView: View {

    let word: Word
    var height: CGFloat = ImagePlaceholder.Metrics.defaultHeight

    @State private var image: UIImage?
    @State private var isLoaded = false

    private let cache = ImageCacheService.shared

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                ImagePlaceholder(
                    symbolName: word.partOfSpeech.placeholderSymbol,
                    height: height
                )
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: word.id) {
            await load()
        }
    }

    private func load() async {
        image = nil
        isLoaded = false
        guard let url = word.imageURL else { return }

        let data = await cache.imageData(for: word.id, url: url)
        guard let data, let decoded = UIImage(data: data) else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            image = decoded
            isLoaded = true
        }
    }
}
