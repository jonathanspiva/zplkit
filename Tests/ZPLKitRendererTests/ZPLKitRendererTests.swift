import XCTest
@testable import ZPLKitRenderer
@testable import ZPLKit

final class ZPLKitRendererTests: XCTestCase {

    func testBasicParsing() throws {
        let zpl = """
        ^XA
        ^PW812
        ^LL406
        ^FO50,50^A0N,30,30^FDHello World^FS
        ^XZ
        """

        let parsed = try ZPLParser.parse(zpl)

        XCTAssertEqual(parsed.width, 812)
        XCTAssertEqual(parsed.height, 406)
        XCTAssertEqual(parsed.elements.count, 1)
    }

    func testBoxParsing() throws {
        let zpl = """
        ^XA
        ^PW812
        ^LL406
        ^FO100,100^GB200,150,3,B,2^FS
        ^XZ
        """

        let parsed = try ZPLParser.parse(zpl)

        XCTAssertEqual(parsed.elements.count, 1)

        if case .box(let box) = parsed.elements.first {
            XCTAssertEqual(box.x, 100)
            XCTAssertEqual(box.y, 100)
            XCTAssertEqual(box.width, 200)
            XCTAssertEqual(box.height, 150)
            XCTAssertEqual(box.thickness, 3)
        } else {
            XCTFail("Expected box element")
        }
    }

    func testBasicRendering() throws {
        let zpl = """
        ^XA
        ^PW200
        ^LL100
        ^FO10,10^A0N,20,20^FDTest^FS
        ^XZ
        """

        let renderer = ZPLRenderer()
        let result = try renderer.render(zpl, dpi: .dpi203)

        XCTAssertEqual(result.image.width, 200)
        XCTAssertEqual(result.image.height, 100)
        XCTAssertGreaterThan(result.metrics.totalTimeSeconds, 0)
    }

    func testRenderMetrics() throws {
        let zpl = """
        ^XA
        ^PW400
        ^LL200
        ^FO50,50^FDHello^FS
        ^XZ
        """

        let renderer = ZPLRenderer()
        let result = try renderer.render(zpl, dpi: .dpi203)

        XCTAssertGreaterThan(result.metrics.parseTimeSeconds, 0)
        XCTAssertGreaterThan(result.metrics.renderTimeSeconds, 0)
        XCTAssertEqual(result.metrics.imageWidth, 400)
        XCTAssertEqual(result.metrics.imageHeight, 200)
    }

    func testPNGExport() throws {
        let zpl = """
        ^XA
        ^PW200
        ^LL100
        ^FO10,10^GB50,50,2^FS
        ^XZ
        """

        let renderer = ZPLRenderer()
        let (data, metrics) = try renderer.renderToPNG(zpl, dpi: .dpi203)

        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(metrics.imageWidth, 200)

        // Verify it's valid PNG data (PNG magic bytes)
        let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        let dataBytes = [UInt8](data.prefix(4))
        XCTAssertEqual(dataBytes, pngMagic)
    }
}
