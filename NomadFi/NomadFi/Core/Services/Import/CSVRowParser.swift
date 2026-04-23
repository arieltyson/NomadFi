// CSVRowParser.swift
// NomadFi
//
// Pure, deterministic CSV tokenizer. Correctly handles:
//   - quoted fields
//   - escaped quotes inside quoted fields (RFC 4180 style: `""`)
//   - commas inside quoted fields
//   - CRLF and LF line endings
//   - blank lines
//   - UTF-8 byte-order marks at the start of the file
//   - trailing empty fields
//
// Never splits on bare `,` / `\n` — that would corrupt quoted fields.
// Has no logger, no concurrency, no SwiftUI; exists as an `enum`
// namespace so every call is a value transformation the tests can
// exercise without ceremony.

import Foundation

/// Low-level CSV / delimited-text tokenizer. Returns a rectangular
/// matrix of rows, with each row split into fields in the exact
/// order they appeared in the source text.
enum CSVRowParser {

    /// Column delimiter. Defaults to `,`; pass `\t` for TSV exports.
    enum Delimiter: Sendable, Equatable {
        case comma
        case tab
        case custom(Character)

        var character: Character {
            switch self {
            case .comma: ","
            case .tab: "\t"
            case .custom(let c): c
            }
        }
    }

    /// Tokenizes CSV / TSV text into rows of string fields.
    ///
    /// - Parameters:
    ///   - text: Raw file text, already decoded to `String`.
    ///   - delimiter: Column delimiter; defaults to `,`.
    /// - Returns: An array of rows. Empty source → empty array.
    ///   A trailing newline does **not** emit a spurious empty row.
    static func rows(
        from text: String,
        delimiter: Delimiter = .comma
    ) -> [[String]] {
        guard !text.isEmpty else { return [] }

        // Strip a leading UTF-8 BOM — some issuer exports carry one.
        var working = text
        if working.first == "\u{FEFF}" {
            working.removeFirst()
        }

        let delim = delimiter.character

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var iterator = working.makeIterator()

        func finishField() {
            currentRow.append(currentField)
            currentField = ""
        }

        func finishRow() {
            // RFC 4180: a line-terminator after a field finalizes
            // that field and the row. Do not emit rows for trailing
            // blank lines.
            currentRow.append(currentField)
            currentField = ""
            rows.append(currentRow)
            currentRow = []
        }

        while let character = iterator.next() {
            if inQuotes {
                if character == "\"" {
                    // Peek for the RFC-4180 escape `""` — the scanner
                    // is Character-by-Character, so we have to look
                    // at the next character through a second fetch.
                    if let peek = iterator.next() {
                        if peek == "\"" {
                            currentField.append("\"")
                        } else {
                            // End of quoted run; push `peek` back
                            // through the ordinary state machine.
                            inQuotes = false
                            processUnquoted(
                                peek,
                                delimiter: delim,
                                currentField: &currentField,
                                currentRow: &currentRow,
                                rows: &rows,
                                inQuotes: &inQuotes
                            )
                        }
                    } else {
                        // End-of-input closes the quoted run and the
                        // field/row implicitly.
                        inQuotes = false
                    }
                } else {
                    currentField.append(character)
                }
                continue
            }

            processUnquoted(
                character,
                delimiter: delim,
                currentField: &currentField,
                currentRow: &currentRow,
                rows: &rows,
                inQuotes: &inQuotes
            )
        }

        // Flush any partially-built field / row. A source ending
        // without a terminator still counts as a full row.
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        // Drop fully-empty rows so a trailing newline or a blank
        // line between records doesn't surface as ingestible data.
        return rows.filter { row in
            row.contains { !$0.isEmpty }
        }
    }

    // MARK: - Private

    /// State transition for an unquoted character. Extracted so the
    /// post-quote "push the peek back" path can reuse it.
    private static func processUnquoted(
        _ character: Character,
        delimiter: Character,
        currentField: inout String,
        currentRow: inout [String],
        rows: inout [[String]],
        inQuotes: inout Bool
    ) {
        switch character {
        case "\"":
            // Opening quote only counts when the current field is
            // empty — otherwise it's a literal quote character in
            // an unquoted field (rare, but defensive).
            if currentField.isEmpty {
                inQuotes = true
            } else {
                currentField.append("\"")
            }
        case delimiter:
            currentRow.append(currentField)
            currentField = ""
        case "\n", "\r", "\r\n":
            // Swift collapses "\r\n" into a single grapheme cluster,
            // so CRLF never arrives as two separate characters — we
            // handle all three terminator shapes in one branch. A
            // blank row (row empty, field empty) is ignored so
            // consecutive terminators don't produce empty records.
            if currentRow.isEmpty && currentField.isEmpty {
                return
            }
            currentRow.append(currentField)
            currentField = ""
            rows.append(currentRow)
            currentRow = []
        default:
            currentField.append(character)
        }
    }
}
