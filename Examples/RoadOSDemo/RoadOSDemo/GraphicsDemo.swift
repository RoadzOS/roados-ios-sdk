import RoadOSGraphics
import SwiftUI

/// Custom vector graphics unrelated to the hazard catalogue: shapes, gradients,
/// Bézier paths, text, groups and transforms, all rendered by the C++ core.
struct GraphicsDemo: View {
    @State private var angle: Double = 20
    @State private var showHazard = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RoadOSCanvas(id: Key(angle: angle, showHazard: showHazard), width: 360, height: 240) { g in
                        drawScene(g, angle: angle, showHazard: showHazard)
                    }
                    .listRowInsets(EdgeInsets())
                }
                Section("Controls") {
                    LabeledContent("Rotation") {
                        Slider(value: $angle, in: 0...360)
                    }
                    Toggle("Overlay a hazard icon", isOn: $showHazard)
                }
                Section("Engine") {
                    LabeledContent("RoadOS core", value: RoadOSGraphics.coreVersion)
                }
            }
            .navigationTitle("Custom graphics")
        }
    }

    private struct Key: Hashable, Sendable {
        let angle: Double
        let showHazard: Bool
    }
}

/// Draws a small road scene. Coordinates are in a 360×240 canvas.
private func drawScene(_ g: RoadOSGraphics, angle: Double, showHazard: Bool) {
    // Sky: vertical linear gradient.
    g.rect {
        $0.width = 360; $0.height = 240
        $0.fill = .linearGradient(from: .zero, to: CGPoint(x: 0, y: 240),
                                  stops: [.init(0, "#0B2A5E"), .init(0.6, "#4C8DF6"), .init(1, "#BFD9FF")])
    }
    // Sun: radial gradient with transparency.
    g.circle {
        $0.centerX = 290; $0.centerY = 60; $0.radius = 42
        $0.fill = .radialGradient(center: CGPoint(x: 290, y: 60), radius: 42,
                                  stops: [.init(0, "#FFE38A"), .init(0.7, "#FFB000"), .init(1, "#FFB00000")])
    }
    // Hills: cubic and quadratic Béziers.
    g.path {
        $0.data = "M0 170 C 60 120, 120 120, 180 160 S 300 130, 360 150 L 360 240 L 0 240 Z"
        $0.fill = "#2FAE5A"
    }
    // Road in perspective.
    g.polygon {
        $0.points = [CGPoint(x: 150, y: 150), CGPoint(x: 210, y: 150), CGPoint(x: 330, y: 240), CGPoint(x: 30, y: 240)]
        $0.fill = "#2A3138"
    }
    // Dashed centre line.
    g.line {
        $0.x1 = 180; $0.y1 = 152; $0.x2 = 180; $0.y2 = 240
        $0.stroke = "#F2C230"; $0.strokeWidth = 4; $0.dash = [12, 10]; $0.lineCap = .round
    }
    // A rotated star in a group with opacity.
    g.group(transform: CGAffineTransform(translationX: 70, y: 70), opacity: 0.9) { s in
        s.polygon {
            $0.points = (0..<10).map { i in
                let r: CGFloat = i % 2 == 0 ? 34 : 14
                let a = CGFloat(i) * .pi / 5 - .pi / 2
                return CGPoint(x: r * cos(a), y: r * sin(a))
            }
            $0.fill = "#FFFFFF"
            $0.stroke = "#111821"; $0.strokeWidth = 2; $0.lineJoin = .round
            $0.rotate(degrees: angle)
        }
    }
    g.text {
        $0.text = "RoadOS"; $0.x = 180; $0.y = 36
        $0.fontFamily = "Inter, 'Helvetica Neue', Arial, sans-serif"; $0.fontSize = 28; $0.fontWeight = 800
        $0.anchor = .middle; $0.baseline = .central; $0.fill = "#FFFFFF"
    }
    if showHazard {
        // An RVHL icon composed into the same scene.
        g.hazard(RoadOSHazard.create("RDM-003") { $0.distanceMeters = 120 }, in: CGRect(x: 236, y: 120, width: 96, height: 96))
    }
}
