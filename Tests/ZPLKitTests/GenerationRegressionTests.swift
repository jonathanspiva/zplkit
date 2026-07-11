import Testing
@testable import ZPLKit

/// Regression tests for generation-module defects found in the 2026-07-10
/// code-review pass.
@Suite("Generation Regression Tests")
struct GenerationRegressionTests {

    // MARK: - Control characters in field data

    @Test("Control characters are hex-escaped so barcode data survives intact")
    func controlCharactersEscaped() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("AB\nCD", at: .dots(50, 50))
        }
        let zpl = label.render()
        // Firmware strips raw LF from the format stream, silently encoding
        // "ABCD"; the _0A escape (under ^FH) preserves the byte.
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("AB_0ACD"))
    }

    // MARK: - ^CI28 for non-ASCII text

    @Test("Non-ASCII content makes the label emit ^CI28")
    func nonASCIIEmitsCI28() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("café", at: .dots(50, 50))
        }
        let zpl = label.render()
        // Without ^CI28, the printer's CP850 default decodes the escaped UTF-8
        // bytes (_C3_A9) as two mojibake glyphs.
        #expect(zpl.contains("^CI28"))
        #expect(zpl.contains("caf_C3_A9"))
    }

    @Test("ASCII-only labels do not emit ^CI28")
    func asciiOnlyOmitsCI28() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("plain", at: .dots(50, 50))
            Text("escaped_underscore", at: .dots(50, 100))
        }
        let zpl = label.render()
        #expect(!zpl.contains("^CI28"))
        // The underscore escape (_5F, below 0x80) must not trigger ^CI28.
        #expect(zpl.contains("_5F"))
    }

    // MARK: - TextBlock backslash escaping

    @Test("TextBlock doubles literal backslashes for ^FB field data")
    func textBlockEscapesBackslashes() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("C:\\labels", at: .dots(50, 50), width: .dots(400))
        }
        // In ^FB data, backslash introduces escapes; a literal one is \\.
        #expect(label.render().contains("C:\\\\labels"))
    }

    @Test("TextBlock newline still becomes the \\& line break")
    func textBlockNewline() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("line1\nline2", at: .dots(50, 50), width: .dots(400))
        }
        #expect(label.render().contains("line1\\&line2"))
    }

    // MARK: - DataMatrix parameter slots

    @Test("DataMatrix rows without columns keeps rows in its own slot")
    func dataMatrixRowsOnly() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DataMatrix("X", at: .dots(50, 50))
                .rows(20)
        }
        // ^BXo,h,s,c,r: with columns omitted, an empty slot must hold rows
        // in the 5th position instead of letting it slide into columns.
        #expect(label.render().contains(",,20"))
    }

    // MARK: - Template substitution

    @Test("Substituted values containing placeholders are not re-expanded")
    func substitutionSinglePass() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("{{ab}} {{c}}", at: .dots(50, 50))
        }
        let zpl = label.render(substituting: ["ab": "{{c}}", "c": "SECRET"])
        // The literal "{{c}}" arriving via the ab-value must stay literal;
        // only the template's own {{c}} placeholder is substituted.
        #expect(zpl.contains("{{c}} SECRET"))
        #expect(!zpl.contains("SECRET SECRET"))
    }
}
