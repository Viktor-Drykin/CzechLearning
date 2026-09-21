//
//  CzechLearningUITests.swift
//  CzechLearningUITests
//
//  Сквозная проверка сценариев раздела 15 ТЗ: импорт при первом старте,
//  полный цикл сессии, переключение вкладок.
//

import XCTest

final class CzechLearningUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    @MainActor
    func testImportsVocabularyAndShowsDecks() throws {
        let app = launchApp()

        // Импорт занимает секунды, дальше показывается главный экран.
        let title = app.staticTexts["Учить"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30), "Главный экран не появился")

        // Колоды подтверждают, что импортировался настоящий словарь.
        XCTAssertTrue(app.staticTexts["0 из 694"].waitForExistence(timeout: 5), "Колода A1")
        XCTAssertTrue(app.staticTexts["0 из 559"].exists, "Колода A2")
    }

    @MainActor
    func testFlashcardSessionRunsFullCycle() throws {
        let app = launchApp()

        let start = app.buttons["Начать"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 30), "Кнопка «Начать» не появилась")
        start.tap()

        let reveal = app.buttons["Показать ответ"].firstMatch
        XCTAssertTrue(reveal.waitForExistence(timeout: 5), "Лицевая сторона карточки")
        reveal.tap()

        // На обороте — четыре кнопки оценки в порядке «Снова → Трудно → Хорошо → Легко».
        for title in ["Снова", "Трудно", "Хорошо", "Легко"] {
            XCTAssertTrue(app.buttons[title].firstMatch.waitForExistence(timeout: 5), "Кнопка «\(title)»")
        }

        // Десять карточек подряд с оценкой «Легко» доводят сессию до итогов.
        for _ in 0..<10 {
            let easy = app.buttons["Легко"].firstMatch
            if easy.waitForExistence(timeout: 3) {
                easy.tap()
            }
            let next = app.buttons["Показать ответ"].firstMatch
            if next.waitForExistence(timeout: 3) {
                next.tap()
            }
        }

        let summary = app.staticTexts["Сессия завершена"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "Экран итогов не показан")
        XCTAssertTrue(app.buttons["Готово"].firstMatch.exists)
    }

    @MainActor
    func testTabsAreReachable() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Учить"].firstMatch.waitForExistence(timeout: 30))

        for tab in ["Словарь", "Прогресс", "Учить"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Вкладка «\(tab)»")
            button.tap()
        }
    }
}
