// CSVRowParserTests.swift
// NomadFi
//
// Pure tokenizer tests. No SwiftData, no simulator dependencies —
// these are the fastest part of the import suite and pin every
// edge case the downstream profile + service layers rely on.
//
// Every fixture here is synthetic. No real issuer exports, no
// private testbed data.

import Foundation
import Testing

@testable import NomadFi

struct CSVRowParserTests {

    // MARK: - Simple rows

    @Test("Single-row CSV splits on unquoted commas")
    func basicRow() {
        let rows = CSVRowParser.rows(from: "2026-01-01,Coffee Shop,4.75")
        #expect(rows == [["2026-01-01", "Coffee Shop", "4.75"]])
    }

    @Test("Multi-row CSV handles LF and CRLF line endings equivalently")
    func lfAndCRLF() {
        let lf = "2026-01-01,Coffee,4.75\n2026-01-02,Bagel,3.00"
        let crlf = "2026-01-01,Coffee,4.75\r\n2026-01-02,Bagel,3.00"
        #expect(CSVRowParser.rows(from: lf) == CSVRowParser.rows(from: crlf))
        #expect(CSVRowParser.rows(from: lf).count == 2)
    }

    @Test("Trailing newline does not emit an extra empty row")
    func trailingNewlineIgnored() {
        let rows = CSVRowParser.rows(from: "a,b,c\n")
        #expect(rows == [["a", "b", "c"]])
    }

    @Test("Empty input returns an empty array")
    func emptyInput() {
        #expect(CSVRowParser.rows(from: "") == [])
    }

    // MARK: - Quoting

    @Test("Comma inside quotes stays in the field")
    func commaInsideQuotes() {
        let rows = CSVRowParser.rows(from: "\"Rent, August\",1200")
        #expect(rows == [["Rent, August", "1200"]])
    }

    @Test("Escaped quote inside quotes decodes to a single quote")
    func escapedQuoteInsideQuotes() {
        let rows = CSVRowParser.rows(from: "\"She said \"\"hi\"\"\",ok")
        #expect(rows == [["She said \"hi\"", "ok"]])
    }

    @Test("Quote closing inline resumes normal parsing")
    func quotedThenUnquoted() {
        let rows = CSVRowParser.rows(from: "\"Coffee\",4.75,USD")
        #expect(rows == [["Coffee", "4.75", "USD"]])
    }

    @Test("Newline inside a quoted field stays in the field")
    func newlineInsideQuotes() {
        let rows = CSVRowParser.rows(from: "\"Line1\nLine2\",ok")
        #expect(rows == [["Line1\nLine2", "ok"]])
    }

    // MARK: - Edge shapes

    @Test("UTF-8 BOM at the start of the file is ignored")
    func utf8BOMIsStripped() {
        let withBOM = "\u{FEFF}a,b,c"
        let rows = CSVRowParser.rows(from: withBOM)
        #expect(rows == [["a", "b", "c"]])
    }

    @Test("Trailing empty field is preserved")
    func trailingEmptyField() {
        let rows = CSVRowParser.rows(from: "a,b,")
        #expect(rows == [["a", "b", ""]])
    }

    @Test("Blank lines between rows are dropped")
    func blankLinesAreDropped() {
        let source = "a,b\n\n\nc,d\n"
        let rows = CSVRowParser.rows(from: source)
        #expect(rows == [["a", "b"], ["c", "d"]])
    }

    @Test("Tab delimiter parses TSV input")
    func tabDelimiter() {
        let rows = CSVRowParser.rows(
            from: "a\tb\tc",
            delimiter: .tab
        )
        #expect(rows == [["a", "b", "c"]])
    }

    @Test("Source ending without a terminator still emits the final row")
    func unterminatedFinalRow() {
        let rows = CSVRowParser.rows(from: "a,b\nc,d")
        #expect(rows == [["a", "b"], ["c", "d"]])
    }
}
