import CoreGraphics
import RoadOSBridge

public enum RoadOSLineCap: Int, Sendable { case butt = 0, round, square }
public enum RoadOSLineJoin: Int, Sendable { case miter = 0, round, bevel }
public enum RoadOSBlendMode: Int, Sendable {
    case sourceOver = 0, source, clear, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn
    case hardLight, softLight, difference, exclusion, plus, hue, saturation, color, luminosity
}
public enum RoadOSTextAnchor: Int, Sendable { case start = 0, middle, end }
public enum RoadOSTextBaseline: Int, Sendable { case alphabetic = 0, central, top, bottom }

/// Fill, stroke and transform shared by every shape. Defaults follow SVG:
/// with neither fill nor stroke set, closed shapes are filled black.
public struct RoadOSStyle: Sendable, Equatable {
    public var fill: RoadOSPaint?
    public var stroke: RoadOSPaint?
    public var strokeWidth: CGFloat = 1
    public var lineCap: RoadOSLineCap = .butt
    public var lineJoin: RoadOSLineJoin = .miter
    public var miterLimit: CGFloat = 4
    public var dash: [CGFloat] = []
    public var dashOffset: CGFloat = 0
    public var opacity: CGFloat = 1
    public var blendMode: RoadOSBlendMode = .sourceOver
    public var transform: CGAffineTransform = .identity

    public init() {}

    func bridged() throws(RoadOSError) -> ROSStyle {
        let s = ROSStyle()
        if let fill { s.fill = try fill.bridged("fill") }
        if let stroke { s.stroke = try stroke.bridged("stroke") }
        s.strokeWidth = Float(strokeWidth)
        s.lineCap = lineCap.rawValue
        s.lineJoin = lineJoin.rawValue
        s.miterLimit = Float(miterLimit)
        s.dash = dash.map { NSNumber(value: Float($0)) }
        s.dashOffset = Float(dashOffset)
        s.opacity = Float(opacity)
        s.blend = blendMode.rawValue
        s.transform = transform
        return s
    }
}

/// A shape description with a style. Style properties are exposed directly,
/// so builder closures read naturally: `$0.fill = "#2196F3"`.
public protocol RoadOSStyled {
    var style: RoadOSStyle { get set }
}

public extension RoadOSStyled {
    var fill: RoadOSPaint? { get { style.fill } set { style.fill = newValue } }
    var stroke: RoadOSPaint? { get { style.stroke } set { style.stroke = newValue } }
    var strokeWidth: CGFloat { get { style.strokeWidth } set { style.strokeWidth = newValue } }
    var lineCap: RoadOSLineCap { get { style.lineCap } set { style.lineCap = newValue } }
    var lineJoin: RoadOSLineJoin { get { style.lineJoin } set { style.lineJoin = newValue } }
    var dash: [CGFloat] { get { style.dash } set { style.dash = newValue } }
    var opacity: CGFloat { get { style.opacity } set { style.opacity = newValue } }
    var blendMode: RoadOSBlendMode { get { style.blendMode } set { style.blendMode = newValue } }
    var transform: CGAffineTransform { get { style.transform } set { style.transform = newValue } }

    /// Rotates by `degrees` (clockwise in the y-down canvas) around `point`.
    mutating func rotate(degrees: CGFloat, around point: CGPoint = .zero) {
        let r = degrees * .pi / 180
        style.transform = style.transform
            .concatenating(CGAffineTransform(translationX: -point.x, y: -point.y)
                .concatenating(CGAffineTransform(rotationAngle: r))
                .concatenating(CGAffineTransform(translationX: point.x, y: point.y)))
    }

    mutating func scale(x: CGFloat, y: CGFloat? = nil, around point: CGPoint = .zero) {
        style.transform = style.transform
            .concatenating(CGAffineTransform(translationX: -point.x, y: -point.y)
                .concatenating(CGAffineTransform(scaleX: x, y: y ?? x))
                .concatenating(CGAffineTransform(translationX: point.x, y: point.y)))
    }

    mutating func translate(x: CGFloat, y: CGFloat) {
        style.transform = style.transform.concatenating(CGAffineTransform(translationX: x, y: y))
    }
}

public struct RoadOSCircle: RoadOSStyled, Sendable, Equatable {
    public var centerX: CGFloat = 0, centerY: CGFloat = 0, radius: CGFloat = 0
    public var style = RoadOSStyle()
    public init() {}
}

public struct RoadOSEllipse: RoadOSStyled, Sendable, Equatable {
    public var centerX: CGFloat = 0, centerY: CGFloat = 0, radiusX: CGFloat = 0, radiusY: CGFloat = 0
    public var style = RoadOSStyle()
    public init() {}
}

/// Rectangle; a non-zero `cornerRadius` makes it a rounded rectangle.
public struct RoadOSRect: RoadOSStyled, Sendable, Equatable {
    public var x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 0, height: CGFloat = 0
    public var cornerRadius: CGFloat = 0
    /// Vertical corner radius; nil = same as `cornerRadius`.
    public var cornerRadiusY: CGFloat?
    public var style = RoadOSStyle()
    public init() {}
}

public struct RoadOSLine: RoadOSStyled, Sendable, Equatable {
    public var x1: CGFloat = 0, y1: CGFloat = 0, x2: CGFloat = 0, y2: CGFloat = 0
    public var style = RoadOSStyle()
    public init() {}
}

/// Open polyline or closed polygon through `points`.
public struct RoadOSPolyline: RoadOSStyled, Sendable, Equatable {
    public var points: [CGPoint] = []
    public var closed = false
    public var style = RoadOSStyle()
    public init() {}
}

/// Arbitrary vector path from SVG path data (M, L, H, V, C, S, Q, T, A, Z).
public struct RoadOSPath: RoadOSStyled, Sendable, Equatable {
    public var data = ""
    public var evenOdd = false
    public var style = RoadOSStyle()
    public init() {}
}

public struct RoadOSText: RoadOSStyled, Sendable, Equatable {
    public var text = ""
    public var x: CGFloat = 0, y: CGFloat = 0
    /// CSS font-family list, resolved by the core: "Inter, 'Helvetica Neue', sans-serif".
    public var fontFamily = "sans-serif"
    public var fontSize: CGFloat = 16
    public var fontWeight = 400
    public var italic = false
    public var anchor: RoadOSTextAnchor = .start
    public var baseline: RoadOSTextBaseline = .alphabetic
    public var style = RoadOSStyle()
    public init() {}
}

/// SVG markup placed into a box (width/height 0 = intrinsic size), aspect-fit.
public struct RoadOSSVG: RoadOSStyled, Sendable, Equatable {
    public var markup = ""
    public var x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 0, height: CGFloat = 0
    public var style = RoadOSStyle()
    public init() {}
}
