//
//  ImageCacheService.swift
//  CzechVocab / Services
//
//  Картинки слов с дисковым кэшем (ТЗ раздел 10).
//
//  Свой кэш поверх URLCache нужен по содержательной причине: loremflickr на один
//  и тот же URL отдаёт разные изображения, а слово должно привязываться к одному
//  образу. Поэтому ключ кэша — id слова, а не URL, и первая удачная загрузка
//  фиксируется навсегда.
//

import Foundation
import OSLog
import UIKit

actor ImageCacheService {

    static let shared = ImageCacheService()

    private let session: URLSession
    private let directory: URL
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.CzechLearning", category: "images")

    /// Слова, по которым загрузка уже провалилась: в рамках запуска не повторяем (ТЗ 10).
    private var failedIDs: Set<Int> = []
    /// Идущие загрузки — чтобы два показа одной карточки не качали дважды.
    private var inFlight: [Int: Task<Data?, Never>] = [:]

    private enum Limits {
        static let memoryCapacity = 50 * 1024 * 1024
        static let diskCapacity = 200 * 1024 * 1024
        static let requestTimeout: TimeInterval = 10
        static let prefetchCount = 20
        static let prefetchConcurrency = 4
    }

    /// - Parameter protocolClasses: подмена сетевого слоя в тестах;
    ///   в приложении всегда `nil` — ходим обычным `URLSession`.
    init(directory: URL? = nil, protocolClasses: [AnyClass]? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: Limits.memoryCapacity,
            diskCapacity: Limits.diskCapacity,
            diskPath: "word-images"
        )
        configuration.timeoutIntervalForRequest = Limits.requestTimeout
        // Low Data Mode: картинки не грузим (ТЗ 10).
        configuration.allowsConstrainedNetworkAccess = false
        configuration.waitsForConnectivity = false
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        session = URLSession(configuration: configuration)

        if let directory {
            self.directory = directory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            self.directory = (caches ?? URL.temporaryDirectory).appending(path: "WordImages")
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    // MARK: - Чтение

    /// Данные картинки: сначала диск, потом сеть. `nil` — показываем плейсхолдер.
    func imageData(for wordID: Int, url: URL?) async -> Data? {
        if let cached = diskData(for: wordID) { return cached }
        guard let url, !failedIDs.contains(wordID) else { return nil }

        if let running = inFlight[wordID] {
            return await running.value
        }

        let task = Task<Data?, Never> { [session, logger] in
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      UIImage(data: data) != nil
                else {
                    return nil
                }
                return data
            } catch {
                logger.debug("Картинка \(wordID) не загрузилась: \(error.localizedDescription)")
                return nil
            }
        }
        inFlight[wordID] = task

        let data = await task.value
        inFlight[wordID] = nil

        guard let data else {
            failedIDs.insert(wordID)
            return nil
        }
        writeToDisk(data, for: wordID)
        return data
    }

    // MARK: - Префетч

    /// Подгружает картинки для начала очереди, пока пользователь смотрит первую карточку.
    func prefetch(_ items: [(id: Int, url: URL)]) async {
        let batch = items.prefix(Limits.prefetchCount)
        guard !batch.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            var running = 0
            for item in batch {
                if running >= Limits.prefetchConcurrency {
                    await group.next()
                    running -= 1
                }
                group.addTask { [weak self] in
                    _ = await self?.imageData(for: item.id, url: item.url)
                }
                running += 1
            }
        }
    }

    // MARK: - Диск

    /// Файл `<id>.jpg` — стабильный ключ, не зависящий от URL.
    private func fileURL(for wordID: Int) -> URL {
        directory.appending(path: "\(wordID).jpg")
    }

    private func diskData(for wordID: Int) -> Data? {
        try? Data(contentsOf: fileURL(for: wordID))
    }

    private func writeToDisk(_ data: Data, for wordID: Int) {
        do {
            try data.write(to: fileURL(for: wordID), options: .atomic)
        } catch {
            logger.debug("Не удалось сохранить картинку \(wordID): \(error.localizedDescription)")
        }
    }

    /// Есть ли картинка на диске — для проверки офлайн-доступности.
    func hasCachedImage(for wordID: Int) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: wordID).path(percentEncoded: false))
    }

    /// Очистка кэша: вызывается при сбросе прогресса.
    func clear() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        failedIDs.removeAll()
    }
}
