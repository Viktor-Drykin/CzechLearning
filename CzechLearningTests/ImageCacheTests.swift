//
//  ImageCacheTests.swift
//  CzechLearningTests
//
//  Кэш картинок на подменённом URLProtocol: реальных запросов к loremflickr
//  в тестах нет (требование приватности из раздела 12 ТЗ).
//

import Foundation
import Testing
import UIKit

@testable import CzechLearning

@Suite("Кэш картинок", .serialized)
struct ImageCacheTests {

    // MARK: - Инструменты

    /// Минимальный валидный JPEG: сервис проверяет, что данные декодируются.
    private static func makeJPEG(color: UIColor) -> Data {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    private func makeCache() -> (ImageCacheService, URL) {
        let directory = URL.temporaryDirectory.appending(path: "ImageCacheTests-\(UUID().uuidString)")
        let cache = ImageCacheService(
            directory: directory,
            protocolClasses: [StubURLProtocol.self]
        )
        return (cache, directory)
    }

    // MARK: - Диск

    @Test("Загруженная картинка сохраняется на диск и читается офлайн")
    func storesAndReadsFromDisk() async throws {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = Self.makeJPEG(color: .red)
        await StubURLProtocol.setResponse(.success(payload))

        let url = try #require(URL(string: "https://loremflickr.com/640/480/test"))
        let first = await cache.imageData(for: 42, url: url)
        #expect(first == payload)
        #expect(await cache.hasCachedImage(for: 42))

        // Сеть «отключена», но картинка уже на диске.
        await StubURLProtocol.setResponse(.failure(URLError(.notConnectedToInternet)))
        let offline = await cache.imageData(for: 42, url: url)
        #expect(offline == payload, "Картинка должна читаться с диска без сети")
    }

    @Test("Картинка стабильна между показами, даже если сервер отдаёт другую")
    func imageStaysStableAcrossShows() async throws {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }

        let original = Self.makeJPEG(color: .green)
        await StubURLProtocol.setResponse(.success(original))

        let url = try #require(URL(string: "https://loremflickr.com/640/480/dog"))
        let first = await cache.imageData(for: 7, url: url)

        // loremflickr на тот же URL отдаёт другое изображение — карточка
        // обязана показывать прежнее, иначе слово не привязывается к образу.
        await StubURLProtocol.setResponse(.success(Self.makeJPEG(color: .blue)))
        let second = await cache.imageData(for: 7, url: url)

        #expect(first == original)
        #expect(second == original)
    }

    // MARK: - Ошибки

    @Test("Провал загрузки не роняет карточку и не повторяется в рамках сессии")
    func failureIsNotRetried() async throws {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }

        await StubURLProtocol.resetCount()
        await StubURLProtocol.setResponse(.failure(URLError(.timedOut)))

        let url = try #require(URL(string: "https://loremflickr.com/640/480/fail"))
        let first = await cache.imageData(for: 99, url: url)
        let second = await cache.imageData(for: 99, url: url)

        #expect(first == nil)
        #expect(second == nil)
        #expect(await StubURLProtocol.requestCount() == 1, "Повторных попыток быть не должно")
        #expect(await cache.hasCachedImage(for: 99) == false)
    }

    @Test("Слово без картинки не ходит в сеть")
    func missingURLSkipsNetwork() async {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }

        await StubURLProtocol.resetCount()
        let data = await cache.imageData(for: 1, url: nil)

        #expect(data == nil)
        #expect(await StubURLProtocol.requestCount() == 0)
    }

    @Test("Неизображение отбрасывается, а не пишется на диск")
    func rejectsNonImageData() async throws {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }

        await StubURLProtocol.setResponse(.success(Data("не картинка".utf8)))
        let url = try #require(URL(string: "https://loremflickr.com/640/480/html"))

        #expect(await cache.imageData(for: 5, url: url) == nil)
        #expect(await cache.hasCachedImage(for: 5) == false)
    }

    @Test("Очистка кэша удаляет файлы с диска")
    func clearRemovesFiles() async throws {
        let (cache, directory) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }

        await StubURLProtocol.setResponse(.success(Self.makeJPEG(color: .gray)))
        let url = try #require(URL(string: "https://loremflickr.com/640/480/clear"))
        _ = await cache.imageData(for: 3, url: url)
        #expect(await cache.hasCachedImage(for: 3))

        await cache.clear()
        #expect(await cache.hasCachedImage(for: 3) == false)
    }

    // MARK: - Источник картинок

    @Test("Словарь не ссылается ни на какой хост, кроме loremflickr.com")
    func onlyKnownHost() async throws {
        let parser = CSVParser()
        let text = try String(contentsOf: try VocabularyResource.url(), encoding: .utf8)
        let parsed = try parser.parseRows(text, requiredColumns: WordRecord.requiredColumns)

        let hosts = parsed.rows
            .compactMap { $0.optional("image_url") }
            .compactMap { URL(string: $0)?.host() }

        #expect(Set(hosts) == ["loremflickr.com"])
        #expect(hosts.count == 1005)
    }
}

// MARK: - Подменённый URLProtocol

/// Перехватывает сетевые запросы сервиса: тесты не выходят в интернет.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    private actor State {
        var response: Result<Data, Error> = .failure(URLError(.unsupportedURL))
        var count = 0

        func set(_ value: Result<Data, Error>) { response = value }
        func take() -> Result<Data, Error> {
            count += 1
            return response
        }
        func reset() { count = 0 }
        func requests() -> Int { count }
    }

    private static let state = State()

    static func setResponse(_ response: Result<Data, Error>) async {
        await state.set(response)
    }

    static func resetCount() async {
        await state.reset()
    }

    static func requestCount() async -> Int {
        await state.requests()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host() == "loremflickr.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let request = self.request
        Task {
            let result = await Self.state.take()
            switch result {
            case .success(let data):
                if let url = request.url,
                   let response = HTTPURLResponse(
                       url: url,
                       statusCode: 200,
                       httpVersion: nil,
                       headerFields: ["Content-Type": "image/jpeg"]
                   ) {
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    client?.urlProtocol(self, didLoad: data)
                }
                client?.urlProtocolDidFinishLoading(self)
            case .failure(let error):
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}
