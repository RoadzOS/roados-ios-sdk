#if canImport(SwiftUI)
import SwiftUI

/// A RoadOS hazard icon, rendered by the shared C++ engine at the view's size
/// and the screen's scale. Rendering happens off the main actor and is
/// repeated only when the hazard, size or scale changes.
///
///     RoadOSIcon(hazardId: "RDM-003", severity: .high)
///         .frame(width: 64, height: 64)
public struct RoadOSIcon: View {
    private let hazard: RoadOSHazard
    private let catalogue: RoadOSCatalogue?
    @Environment(\.displayScale) private var displayScale
    @State private var rendered: Rendered?

    private struct Rendered {
        let key: Key
        let image: CGImage?
        let error: RoadOSError?
    }

    private struct Key: Hashable {
        let hazard: RoadOSHazard
        let points: Int
        let scale: CGFloat
    }

    public init(hazardId: String, severity: HazardSeverity? = nil, theme: RoadOSTheme = .dark,
                catalogue: RoadOSCatalogue? = nil) {
        var h = RoadOSHazard(hazardId)
        h.severity = severity
        h.theme = theme
        self.init(h, catalogue: catalogue)
    }

    public init(_ hazard: RoadOSHazard, catalogue: RoadOSCatalogue? = nil) {
        self.hazard = hazard
        self.catalogue = catalogue
    }

    public var body: some View {
        GeometryReader { geo in
            let points = max(1, Int(min(geo.size.width, geo.size.height).rounded()))
            let key = Key(hazard: hazard, points: points, scale: displayScale)
            content
                .frame(width: geo.size.width, height: geo.size.height)
                .task(id: key) { await render(key) }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var content: some View {
        if let image = rendered?.image {
            Image(decorative: image, scale: displayScale).resizable().interpolation(.high).scaledToFit()
        } else if rendered?.error != nil {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
        } else {
            Color.clear
        }
    }

    private var accessibilityText: Text {
        if let entry = try? (catalogue ?? RoadOSCatalogue.bundled()).entry(hazard.id) {
            let severity = hazard.severity ?? entry.defaultSeverity
            return Text("\(entry.name), severity \(severity.code)")
        }
        return Text(hazard.id)
    }

    private func render(_ key: Key) async {
        var h = key.hazard
        h.size = key.points
        do {
            let image = try await h.renderAsync(scale: key.scale, catalogue: catalogue)
            rendered = Rendered(key: key, image: image, error: nil)
        } catch {
            rendered = Rendered(key: key, image: nil, error: RoadOSError(error))
        }
    }
}

/// Custom RoadOS graphics in SwiftUI. `draw` runs whenever `id` changes; the
/// scene is then rendered off the main actor at the screen's scale.
///
///     RoadOSCanvas(id: progress, width: 200, height: 200) { g in
///         g.circle { $0.centerX = 100; $0.centerY = 100; $0.radius = 80; $0.fill = "#2196F3" }
///     }
public struct RoadOSCanvas<ID: Hashable & Sendable>: View {
    private let id: ID
    private let width: Int
    private let height: Int
    private let draw: (RoadOSGraphics) -> Void
    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?
    @State private var error: RoadOSError?

    public init(id: ID, width: Int, height: Int, draw: @escaping (RoadOSGraphics) -> Void) {
        self.id = id
        self.width = width
        self.height = height
        self.draw = draw
    }

    public var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: displayScale).resizable().scaledToFit()
            } else if let error {
                Text(error.message).font(.caption).foregroundStyle(.red)
            } else {
                Color.clear
            }
        }
        .aspectRatio(CGFloat(width) / CGFloat(max(height, 1)), contentMode: .fit)
        .task(id: TaskKey(id: id, scale: displayScale)) {
            let g = RoadOSGraphics(width: width, height: height)
            draw(g)
            do {
                image = try await g.renderAsync(scale: displayScale)
                error = nil
            } catch {
                self.error = RoadOSError(error)
            }
        }
    }

    private struct TaskKey: Hashable {
        let id: ID
        let scale: CGFloat
    }
}
#endif
