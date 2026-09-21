//
//  WordImageView.swift
//  CzechVocab / DesignSystem / Components
//
//  Картинка слова с дисковым кэшем и плейсхолдером. Пока картинка грузится,
//  место под неё держит плейсхолдер: карточка не должна прыгать. Если картинки
//  у слова нет в данных, вью не рисует ничего — ни рамки, ни отступа.
//

import SwiftUI

struct WordImageView: View {

    let word: Word
    var height: CGFloat = ImagePlaceholder.Metrics.defaultHeight

    @State private var image: UIImage?

    private let cache = ImageCacheService.shared

    var body: some View {
        // Слов без `image_url` в словаре около трети (служебные части речи,
        // фразы, абстракции). Для них плейсхолдер не информация, а шум,
        // поэтому ветка пустая: VStack родителя не оставит под неё spacing.
        if let url = word.imageURL {
            content(for: url)
        }
    }

    private func content(for url: URL) -> some View {
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
            await load(from: url)
        }
    }

    private func load(from url: URL) async {
        image = nil

        let data = await cache.imageData(for: word.id, url: url)
        guard let data, let decoded = UIImage(data: data) else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            image = decoded
        }
    }
}
