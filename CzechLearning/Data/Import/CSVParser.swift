//
//  CSVParser.swift
//  CzechVocab / Data / Import
//
//  Разбор CSV по RFC 4180 без сторонних зависимостей.
//
//  Особенности исходного файла, которые парсер обязан выдержать:
//  — UTF-8 с BOM (BOM отбрасывается до разбора);
//  — переводы строк CRLF (в файле их 1745, одиночных LF нет);
//  — поля с запятыми и кавычками внутри, экранированные по RFC 4180.
//

import Foundation

nonisolated struct CSVParser {

    /// Одна разобранная строка: заголовки уже сопоставлены с полями.
    struct Row {
        let lineNumber: Int
        private let values: [String: String]

        init(lineNumber: Int, values: [String: String]) {
            self.lineNumber = lineNumber
            self.values = values
        }

        /// Значение колонки без обрезки пробелов. Отсутствующая колонка — пустая строка.
        subscript(column: String) -> String {
            values[column] ?? ""
        }

        /// Значение колонки, обрезанное по краям; пустое превращается в `nil`.
        func optional(_ column: String) -> String? {
            let trimmed = self[column].trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        /// Обязательное значение: обрезанное и непустое.
        func required(_ column: String) -> String? {
            optional(column)
        }
    }

    enum ParseError: Error, Equatable {
        case emptyFile
        case missingColumns([String])
    }

    private let delimiter: Unicode.Scalar
    private let quote: Unicode.Scalar = "\""
    private let carriageReturn: Unicode.Scalar = "\r"
    private let lineFeed: Unicode.Scalar = "\n"

    init(delimiter: Unicode.Scalar = ",") {
        self.delimiter = delimiter
    }

    // MARK: - Разбор в таблицу

    /// Разбирает текст в матрицу полей. Первая строка не выделяется — это делает `parseRows`.
    ///
    /// Разбор идёт по скалярам, а не по `Character`: Swift склеивает `\r\n`
    /// в один графемный кластер, и посимвольный автомат не увидел бы там конца строки.
    func parseTable(_ text: String) -> [[String]] {
        var table: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var insideQuotes = false

        let scalars = Array(stripBOM(text).unicodeScalars)
        var index = 0

        func finishField() {
            row.append(String(field))
            field = String.UnicodeScalarView()
        }

        func finishRow() {
            finishField()
            table.append(row)
            row = []
        }

        while index < scalars.count {
            let scalar = scalars[index]
            index += 1

            if insideQuotes {
                if scalar == quote {
                    // Удвоенная кавычка внутри поля — это одна кавычка.
                    if index < scalars.count, scalars[index] == quote {
                        field.append(quote)
                        index += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
                continue
            }

            switch scalar {
            case quote where field.isEmpty:
                insideQuotes = true
            case delimiter:
                finishField()
            case carriageReturn:
                // CRLF и одиночный CR — оба конец строки.
                if index < scalars.count, scalars[index] == lineFeed {
                    index += 1
                }
                finishRow()
            case lineFeed:
                finishRow()
            default:
                field.append(scalar)
            }
        }

        // Последняя строка без завершающего перевода строки.
        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }

        return table
    }

    // MARK: - Разбор со схемой

    /// Разбирает текст, требуя наличие перечисленных колонок в заголовке.
    /// Пустые строки пропускаются, строки с другим числом полей — тоже (их считает `skippedRows`).
    func parseRows(
        _ text: String,
        requiredColumns: [String]
    ) throws -> (rows: [Row], skippedRows: [Int]) {
        let table = parseTable(text)
        guard let header = table.first else { throw ParseError.emptyFile }

        let columns = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let missing = requiredColumns.filter { !columns.contains($0) }
        guard missing.isEmpty else { throw ParseError.missingColumns(missing) }

        var rows: [Row] = []
        var skipped: [Int] = []
        rows.reserveCapacity(table.count - 1)

        for (offset, fields) in table.dropFirst().enumerated() {
            // Номер строки в файле: +2 за заголовок и нумерацию с единицы.
            let lineNumber = offset + 2

            if fields.count == 1, fields[0].trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            guard fields.count == columns.count else {
                skipped.append(lineNumber)
                continue
            }

            var values: [String: String] = [:]
            values.reserveCapacity(columns.count)
            for (index, column) in columns.enumerated() {
                values[column] = fields[index]
            }
            rows.append(Row(lineNumber: lineNumber, values: values))
        }

        return (rows, skipped)
    }

    // MARK: - Служебное

    /// UTF-8 BOM приходит в начале файла и иначе попал бы в первую колонку заголовка.
    private func stripBOM(_ text: String) -> String {
        guard text.hasPrefix("\u{FEFF}") else { return text }
        return String(text.dropFirst())
    }
}
