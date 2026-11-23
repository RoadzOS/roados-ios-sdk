import CoreGraphics
import XCTest

@testable import RoadOSGraphics

/// Reads un-premultiplied RGBA at (x, y) from a CGImage.
private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
    let a = px[3]
    guard a > 0 else { return (0, 0, 0, 0) }
    func un(_ c: UInt8) -> UInt8 { UInt8(min(255, (Int(c) * 255 + Int(a) / 2) / Int(a))) }
    return (un(px[0]), un(px[1]), un(px[2]), a)
}

final class GraphicsTests: XCTestCase {
    func testCircleFromTheDocumentedExample() throws {
        let graphics = RoadOSGraphics.create {
            $0.width = 512
            $0.height = 512
            $0.background = .transparent
        }
        graphics.circle {
            $0.centerX = 100
            $0.centerY = 100
            $0.radius = 40
            $0.fill = "#2196F3"
        }
        let image = try graphics.render()
        XCTAssertEqual(image.width, 512)
        let c = pixel(image, 100, 100)
        XCTAssertEqual([c.r, c.g, c.b, c.a], [0x21, 0x96, 0xF3, 255])
        XCTAssertEqual(pixel(image, 10, 10).a, 0, "background is transparent")
    }

    func testScaleProducesHighResolutionOutput() throws {
        let g = RoadOSGraphics(width: 64, height: 32)
        g.rect { $0.width = 64; $0.height = 32; $0.fill = "#FF0000" }
        let image = try g.render(scale: 3)
        XCTAssertEqual(image.width, 192)
        XCTAssertEqual(image.height, 96)
    }

    func testStrokeOnlyShapeHasNoFill() throws {
        let g = RoadOSGraphics(width: 40, height: 40)
        g.rect {
            $0.x = 5; $0.y = 5; $0.width = 30; $0.height = 30
            $0.stroke = "#00FF00"
            $0.strokeWidth = 4
        }
        let image = try g.render()
        XCTAssertEqual(pixel(image, 20, 20).a, 0)
        XCTAssertEqual(pixel(image, 5, 20).g, 255)
    }

    func testLinearGradient() throws {
        let g = RoadOSGraphics(width: 100, height: 10)
        g.rect {
            $0.width = 100; $0.height = 10
            $0.fill = .linearGradient(from: .zero, to: CGPoint(x: 100, y: 0),
                                      stops: [.init(0, "#000000"), .init(1, "#FFFFFF")])
        }
        let image = try g.render()
        XCTAssertLessThan(pixel(image, 2, 5).r, 20)
        XCTAssertGreaterThan(pixel(image, 97, 5).r, 235)
        XCTAssertEqual(Int(pixel(image, 50, 5).r), 128, accuracy: 6)
    }

    func testPathTextGroupAndTransform() throws {
        let g = RoadOSGraphics(width: 200, height: 200)
        g.path { $0.data = "M10 10 C 60 0, 140 0, 190 10 L 190 60 Q 100 120 10 60 Z"; $0.fill = "#FFAA00" }
        g.group(transform: CGAffineTransform(translationX: 100, y: 100), opacity: 1) { inner in
            inner.rect { $0.width = 20; $0.height = 20; $0.fill = "#0000FF" }
        }
        g.text { $0.text = "RoadOS"; $0.x = 100; $0.y = 180; $0.fontSize = 20; $0.anchor = .middle; $0.fill = "#000000" }
        let image = try g.render()
        XCTAssertEqual(pixel(image, 110, 110).b, 255, "group translated the blue square")
        XCTAssertEqual(pixel(image, 100, 30).r, 255)
        XCTAssertGreaterThan(try g.svgString().count, 100)
    }

    func testInvalidInputIsReportedAtRender() {
        let g = RoadOSGraphics(width: 10, height: 10)
        g.circle { $0.radius = 3; $0.fill = "#notacolor" }
        g.circle { $0.radius = 3; $0.fill = "#FF0000" }  // later valid calls don't hide the first error
        XCTAssertEqual(g.firstError?.code, .invalidArgument)
        XCTAssertThrowsError(try g.render()) { error in
            XCTAssertTrue("\(error)".contains("notacolor"))
        }
        g.clear()
        XCTAssertNoThrow(try g.render())

        let bad = RoadOSGraphics(width: 10, height: 10)
        bad.path { $0.data = "M0 0 Q" }
        XCTAssertEqual(bad.firstError?.code, .parse)
    }

    func testSVGMarkupRendering() throws {
        let g = RoadOSGraphics(width: 100, height: 100)
        g.svg {
            $0.markup = ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#00FF00"/></svg>"##
            $0.width = 100; $0.height = 100
        }
        XCTAssertEqual(pixel(try g.render(), 50, 50).g, 255)
    }

    func testRenderAsyncUsesASnapshot() async throws {
        let g = RoadOSGraphics(width: 20, height: 20)
        g.rect { $0.width = 20; $0.height = 20; $0.fill = "#FF0000" }
        let pending = Task { [g] in try await g.renderAsync() }
        let image = try await pending.value
        XCTAssertEqual(pixel(image, 10, 10).r, 255)
    }
}

final class HazardTests: XCTestCase {
    func testBundledCatalogue() throws {
        let catalogue = try RoadOSCatalogue.bundled()
        XCTAssertEqual(catalogue.entries.count, 267)
        XCTAssertEqual(catalogue.families.count, 14)
        XCTAssertEqual(catalogue.rvhlVersion, "1.0.0")
        let pothole = try catalogue.entry("RDM-003")
        XCTAssertEqual(pothole.name, "Large pothole")
        XCTAssertEqual(try catalogue.entry("large_pothole"), pothole)
        XCTAssertEqual(catalogue.entries(withGlyph: "pothole").count, 9)
    }

    func testGlyphKeyIsNotAnIdentifier() throws {
        let catalogue = try RoadOSCatalogue.bundled()
        XCTAssertThrowsError(try catalogue.entry("pothole")) { error in
            let e = error as! RoadOSError
            XCTAssertEqual(e.code, .notFound)
            XCTAssertTrue(e.message.contains("RDM-003"), e.message)
        }
    }

    func testHazardRendersAtRequestedSize() throws {
        let hazard = RoadOSHazard.create("RDM-003") {
            $0.severity = .high
            $0.size = 128
            $0.theme = .dark
        }
        let image = try hazard.render(scale: 2)
        XCTAssertEqual(image.width, 256)
        // Frame border (design y≈9, x=40) is the S4 colour #E35D32.
        let border = pixel(image, 80, 18)
        XCTAssertEqual([border.r, border.g, border.b], [0xE3, 0x5D, 0x32])
    }

    func testHazardSVGIsTheStudioFormat() throws {
        let svg = try RoadOSHazard.create("RDM-003") { $0.distanceMeters = 150 }.svg()
        XCTAssertTrue(svg.hasPrefix(#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128""#))
        XCTAssertTrue(svg.contains(#"aria-label="RDM-003 Large pothole""#))
        XCTAssertTrue(svg.contains(">150 m<"))
    }

    func testLayersCanBeTurnedOff() throws {
        let code = try RoadOSCatalogue.bundled().entry("RDM-003").defaultSeverity.code
        let full = try RoadOSHazard.create("RDM-003").svg()
        let bare = try RoadOSHazard.create("RDM-003") { $0.layers = [.pictogram] }.svg()
        XCTAssertTrue(full.contains(">\(code)<"), "severity tab is drawn by default")
        XCTAssertFalse(bare.contains(">\(code)<"))
        XCTAssertThrowsError(try RoadOSHazard.create("RDM-003") { $0.layers = [] }.svg())
    }

    func testUnknownHazardThrows() {
        XCTAssertThrowsError(try RoadOSHazard("NOPE-1").render()) { error in
            XCTAssertEqual((error as? RoadOSError)?.code, .notFound)
        }
    }

    func testHazardInsideCustomGraphics() throws {
        let g = RoadOSGraphics(width: 300, height: 128)
        g.hazard(RoadOSHazard("RDM-003"), in: CGRect(x: 0, y: 0, width: 128, height: 128))
        g.circle { $0.centerX = 250; $0.centerY = 64; $0.radius = 30; $0.fill = "#2196F3" }
        let image = try g.render()
        XCTAssertGreaterThan(pixel(image, 64, 64).a, 0)
        XCTAssertEqual(pixel(image, 250, 64).b, 0xF3)
    }

    func testConcurrentRendering() async throws {
        let catalogue = try RoadOSCatalogue.bundled()
        let ids = catalogue.entries.prefix(40).map(\.id)
        let sizes = try await withThrowingTaskGroup(of: Int.self) { group in
            for id in ids {
                group.addTask { try await RoadOSHazard(id).renderAsync(catalogue: catalogue).width }
            }
            return try await group.reduce(into: [Int]()) { $0.append($1) }
        }
        XCTAssertEqual(sizes.count, 40)
        XCTAssertTrue(sizes.allSatisfy { $0 == 128 })
    }
}
