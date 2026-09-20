//
//  CSVParserTests.swift
//  CzechLearningTests
//

import Foundation
import Testing

@testable import CzechLearning

@Suite("CSV-парсер")
struct CSVParserTests {

    private let parser = CSVParser()

    @Test("Простая таблица разбирается по строкам и полям")
    func plainTable() {
        let table = parser.parseTable("a,b,c\n1,2,3\n")
        #expect(table == [["a", "b", "c"], ["1", "2", "3"]])
    }

    @Test("CRLF — такой же конец строки, как LF")
    func crlfLineEndings() {
        let table = parser.parseTable("a,b\r\n1,2\r\n")
        #expect(table == [["a", "b"], ["1", "2"]])
    }

    @Test("Одиночный CR тоже завершает строку")
    func lonelyCarriageReturn() {
        let table = parser.parseTable("a,b\r1,2")
        #expect(table == [["a", "b"], ["1", "2"]])
    }

    @Test("BOM отбрасывается и не попадает в первую колонку")
    func bomIsStripped() {
        let table = parser.parseTable("\u{FEFF}id,czech\r\n1,konec\r\n")
        #expect(table.first?.first == "id")
    }

    @Test("Запятая внутри кавычек не разделяет поля")
    func commaInsideQuotes() {
        let table = parser.parseTable("a,\"b,c\",d\n")
        #expect(table == [["a", "b,c", "d"]])
    }

    @Test("Удвоенная кавычка внутри поля — одна кавычка")
    func escapedQuote() {
        let table = parser.parseTable("a,\"say \"\"ahoj\"\"\",b\n")
        #expect(table == [["a", "say \"ahoj\"", "b"]])
    }

    @Test("Перевод строки внутри кавычек не завершает строку")
    func newlineInsideQuotes() {
        let table = parser.parseTable("a,\"first\r\nsecond\",b\r\nx,y,z\r\n")
        #expect(table == [["a", "first\r\nsecond", "b"], ["x", "y", "z"]])
    }

    @Test("Пустые поля сохраняются как пустые строки")
    func emptyFields() {
        let table = parser.parseTable("a,,\"\",b\n")
        #expect(table == [["a", "", "", "b"]])
    }

    @Test("Последняя строка без перевода строки не теряется")
    func lastLineWithoutTerminator() {
        let table = parser.parseTable("a,b\n1,2")
        #expect(table.count == 2)
        #expect(table.last == ["1", "2"])
    }

    @Test("Заголовки сопоставляются с полями")
    func rowsMapColumns() throws {
        let result = try parser.parseRows("id,czech\r\n1,konec\r\n", requiredColumns: ["id", "czech"])
        #expect(result.rows.count == 1)
        #expect(result.rows[0]["czech"] == "konec")
        #expect(result.rows[0].lineNumber == 2)
    }

    @Test("Строка с лишним полем пропускается, а не роняет разбор")
    func skipsMalformedRow() throws {
        let result = try parser.parseRows(
            "id,czech\r\n1,konec\r\n2,a,b\r\n3,pozor\r\n",
            requiredColumns: ["id", "czech"]
        )
        #expect(result.rows.count == 2)
        #expect(result.skippedRows == [3])
    }

    @Test("Отсутствие обязательной колонки — ошибка")
    func missingColumn() {
        #expect(throws: CSVParser.ParseError.missingColumns(["level"])) {
            try parser.parseRows("id,czech\r\n1,konec\r\n", requiredColumns: ["id", "level"])
        }
    }

    @Test("Пустой файл — ошибка")
    func emptyFile() {
        #expect(throws: CSVParser.ParseError.emptyFile) {
            try parser.parseRows("", requiredColumns: ["id"])
        }
    }
}
