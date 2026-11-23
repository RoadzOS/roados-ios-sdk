import CoreGraphics
import RoadOSBridge

/// General-purpose vector graphics rendered by the shared C++ / Skia engine.
///
///     let graphics = RoadOSGraphics.create {
///         $0.width = 512
///         $0.height = 512
///         $0.background = .transparent
///     }
///     graphics.circle {
///         $0.centerX = 100
///         $0.centerY = 100
///         $0.radius = 40
///         $0.fill = "#2196F3"
///     }
///     let image = try graphics.render()
///
/// Drawing calls never throw, so they can be chained. The first invalid input
/// (bad colour, malformed path data, negative radius, …) is remembered and
/// thrown by `render()` / `svgString()`; see `firstError`.
///
/// Not thread-safe while building. `renderAsync()` renders an independent
/// snapshot, so the instance can keep being edited meanwhile.
public final class RoadOSGraphics {
    public struct Configuration: Sendable {
        public var width = 512
        public var height = 512
        public var background: RoadOSColor = .transparent
        public init() {}
    }

    private let scene: ROSScene
    public let width: Int
    public let height: Int
    /// The first error recorded by a drawing call, if any.
    public private(set) var firstError: RoadOSError?

    public init(width: Int, height: Int, background: RoadOSColor = .transparent) {
        self.width = width
        self.height = height
        scene = ROSScene(width: width, height: height)
        setBackground(background)
    }

    public static func create(_ configure: (inout Configuration) -> Void = { _ in }) -> RoadOSGraphics {
        var c = Configuration()
        configure(&c)
        return RoadOSGraphics(width: c.width, height: c.height, background: c.background)
    }

    /// Core engine version, e.g. "0.2.0".
    public static var coreVersion: String { ROSCoreVersion() }

    public func setBackground(_ color: RoadOSColor) {
        record { () throws(RoadOSError) in scene.setBackgroundARGB(try color.validated("background")) }
    }

    // MARK: Shapes

    @discardableResult
    public func circle(_ configure: (inout RoadOSCircle) -> Void) -> Self {
        var s = RoadOSCircle(); configure(&s)
        return draw(style: s.style) { st in try scene.addCircleX(Float(s.centerX), y: Float(s.centerY), radius: Float(s.radius), style: st) }
    }

    @discardableResult
    public func ellipse(_ configure: (inout RoadOSEllipse) -> Void) -> Self {
        var s = RoadOSEllipse(); configure(&s)
        return draw(style: s.style) { st in
            try scene.addEllipseX(Float(s.centerX), y: Float(s.centerY), radiusX: Float(s.radiusX), radiusY: Float(s.radiusY), style: st)
        }
    }

    @discardableResult
    public func rect(_ configure: (inout RoadOSRect) -> Void) -> Self {
        var s = RoadOSRect(); configure(&s)
        return draw(style: s.style) { st in
            try scene.addRectX(Float(s.x), y: Float(s.y), width: Float(s.width), height: Float(s.height),
                               radiusX: Float(s.cornerRadius), radiusY: Float(s.cornerRadiusY ?? s.cornerRadius), style: st)
        }
    }

    /// Same as `rect`; reads better when a corner radius is set.
    @discardableResult
    public func roundedRect(_ configure: (inout RoadOSRect) -> Void) -> Self { rect(configure) }

    @discardableResult
    public func line(_ configure: (inout RoadOSLine) -> Void) -> Self {
        var s = RoadOSLine(); configure(&s)
        return draw(style: s.style) { st in try scene.addLineX1(Float(s.x1), y1: Float(s.y1), x2: Float(s.x2), y2: Float(s.y2), style: st) }
    }

    @discardableResult
    public func polyline(_ configure: (inout RoadOSPolyline) -> Void) -> Self {
        var s = RoadOSPolyline(); configure(&s)
        let xy = s.points.flatMap { [NSNumber(value: Float($0.x)), NSNumber(value: Float($0.y))] }
        return draw(style: s.style) { st in try scene.addPolyPoints(xy, closed: s.closed, style: st) }
    }

    @discardableResult
    public func polygon(_ configure: (inout RoadOSPolyline) -> Void) -> Self {
        polyline { s in
            configure(&s)
            s.closed = true
        }
    }

    /// Custom vector path from SVG path data, including cubic and quadratic Béziers.
    @discardableResult
    public func path(_ configure: (inout RoadOSPath) -> Void) -> Self {
        var s = RoadOSPath(); configure(&s)
        return draw(style: s.style) { st in try scene.addPathData(s.data, evenOdd: s.evenOdd, style: st) }
    }

    @discardableResult
    public func text(_ configure: (inout RoadOSText) -> Void) -> Self {
        var s = RoadOSText(); configure(&s)
        return draw(style: s.style) { st in
            try scene.addText(s.text, x: Float(s.x), y: Float(s.y), fontFamilies: s.fontFamily, size: Float(s.fontSize),
                              weight: s.fontWeight, italic: s.italic, anchor: s.anchor.rawValue,
                              baseline: s.baseline.rawValue, style: st)
        }
    }

    /// Renders SVG markup (via Skia's SVG module) into a box.
    @discardableResult
    public func svg(_ configure: (inout RoadOSSVG) -> Void) -> Self {
        var s = RoadOSSVG(); configure(&s)
        return draw(style: s.style) { st in
            try scene.addSVG(s.markup, x: Float(s.x), y: Float(s.y), width: Float(s.width), height: Float(s.height), style: st)
        }
    }

    /// Draws a CGImage into `rect` (zero size = natural size).
    @discardableResult
    public func image(_ image: CGImage, in rect: CGRect, opacity: CGFloat = 1) -> Self {
        var style = RoadOSStyle()
        style.opacity = opacity
        return draw(style: style) { st in
            try scene.add(image, x: Float(rect.minX), y: Float(rect.minY), width: Float(rect.width), height: Float(rect.height), style: st)
        }
    }

    /// Draws a composed RVHL hazard icon into `rect`, so it can be combined with custom graphics.
    @discardableResult
    public func hazard(_ hazard: RoadOSHazard, in rect: CGRect, catalogue: RoadOSCatalogue? = nil) -> Self {
        record { () throws(RoadOSError) in
            let lib = try RoadOSCatalogue.resolve(catalogue)
            let spec = try hazard.spec()
            try bridged {
                try scene.addHazard(spec, library: lib, x: Float(rect.minX), y: Float(rect.minY),
                                    width: Float(rect.width), height: Float(rect.height))
            }
        }
        return self
    }

    /// Draws `content` as a group sharing a transform, opacity and optional clip.
    @discardableResult
    public func group(transform: CGAffineTransform = .identity, opacity: CGFloat = 1, clip: CGRect? = nil,
                      _ content: (RoadOSGraphics) -> Void) -> Self {
        let opened = record { () throws(RoadOSError) in
            try bridged {
                try scene.beginGroupTransform(transform, opacity: Float(opacity), clip: clip != nil, clipRect: clip ?? .zero)
            }
        }
        content(self)
        if opened { record { () throws(RoadOSError) in try bridged { try scene.endGroup() } } }
        return self
    }

    /// Removes everything drawn so far and clears `firstError`.
    public func clear() {
        scene.clear()
        firstError = nil
    }

    // MARK: Output

    /// Renders to a CGImage of `width × scale` by `height × scale` pixels
    /// (premultiplied RGBA, sRGB).
    public func render(scale: CGFloat = 1) throws(RoadOSError) -> CGImage {
        if let firstError { throw firstError }
        return try bridged { try scene.render(withScale: scale) }
    }

    /// Renders a snapshot of the current scene off the calling actor.
    ///
    /// The snapshot is taken on the caller's isolation (so `self` is never sent
    /// across actors); only the immutable copy is rendered on a background task.
    public func renderAsync(scale: CGFloat = 1, isolation: isolated (any Actor)? = #isolation)
        async throws(RoadOSError) -> CGImage {
        if let firstError { throw firstError }
        let snapshot = SceneSnapshot(scene: scene.copy() as! ROSScene)
        let result = await Task.detached(priority: .userInitiated) { () -> Result<CGImage, RoadOSError> in
            do throws(RoadOSError) {
                return .success(try bridged { try snapshot.scene.render(withScale: scale) })
            } catch {
                return .failure(error)
            }
        }.value
        return try result.get()
    }

    /// Serialises the scene to SVG.
    public func svgString() throws(RoadOSError) -> String {
        if let firstError { throw firstError }
        return try bridged { try scene.svg() }
    }

    // MARK: Private

    @discardableResult
    private func record(_ body: () throws(RoadOSError) -> Void) -> Bool {
        do {
            try body()
            return true
        } catch {
            if firstError == nil { firstError = error }
            return false
        }
    }

    private func draw(style: RoadOSStyle, _ add: (ROSStyle) throws -> Void) -> Self {
        record { () throws(RoadOSError) in
            let st = try style.bridged()
            try bridged { try add(st) }
        }
        return self
    }
}

/// An independent copy of a scene, never mutated after creation, so it can be
/// rendered on another thread.
private struct SceneSnapshot: @unchecked Sendable {
    let scene: ROSScene
}
