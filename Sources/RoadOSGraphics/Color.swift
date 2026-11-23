import CoreGraphics
import RoadOSBridge

/// An sRGB colour with straight alpha, stored as 0xAARRGGBB.
///
/// String literals are parsed by the shared C++ core ("#RGB", "#RGBA",
/// "#RRGGBB", "#RRGGBBAA", "transparent"). An invalid literal does not crash;
/// it is reported as an error when the graphic is rendered.
public struct RoadOSColor: Sendable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let argb: UInt32
    /// Set when the colour came from a string the core could not parse.
    public let invalidLiteral: String?

    public init(argb: UInt32) {
        self.argb = argb
        self.invalidLiteral = nil
    }

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.init(argb: UInt32(alpha) << 24 | UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue))
    }

    /// Parses a CSS hex colour. Returns nil if the text is not a valid colour.
    public init?(hex: String) {
        var value: UInt32 = 0
        guard ROSParseColor(hex, &value) else { return nil }
        self.init(argb: value)
    }

    public init(stringLiteral value: String) {
        var parsed: UInt32 = 0
        if ROSParseColor(value, &parsed) {
            self.argb = parsed
            self.invalidLiteral = nil
        } else {
            self.argb = 0
            self.invalidLiteral = value
        }
    }

    public var alpha: UInt8 { UInt8(truncatingIfNeeded: argb >> 24) }
    public var red: UInt8 { UInt8(truncatingIfNeeded: argb >> 16) }
    public var green: UInt8 { UInt8(truncatingIfNeeded: argb >> 8) }
    public var blue: UInt8 { UInt8(truncatingIfNeeded: argb) }

    public var description: String {
        if let invalidLiteral { return "invalid(\(invalidLiteral))" }
        return alpha == 255
            ? String(format: "#%02X%02X%02X", red, green, blue)
            : String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }

    public static let transparent = RoadOSColor(argb: 0x0000_0000)
    public static let black = RoadOSColor(argb: 0xFF00_0000)
    public static let white = RoadOSColor(argb: 0xFFFF_FFFF)

    func validated(_ what: String) throws(RoadOSError) -> UInt32 {
        if let invalidLiteral {
            throw RoadOSError(.invalidArgument, "\(what): \"\(invalidLiteral)\" is not a valid colour")
        }
        return argb
    }
}

public struct RoadOSGradientStop: Sendable, Hashable {
    public var offset: CGFloat
    public var color: RoadOSColor
    public init(_ offset: CGFloat, _ color: RoadOSColor) {
        self.offset = offset
        self.color = color
    }
}

public enum RoadOSSpread: Int, Sendable {
    case pad = 0, `repeat` = 1, reflect = 2
}

/// What a fill or stroke is painted with. Gradient coordinates are in the
/// shape's local coordinate system.
public enum RoadOSPaint: Sendable, Hashable, ExpressibleByStringLiteral {
    case color(RoadOSColor)
    case linearGradient(from: CGPoint, to: CGPoint, stops: [RoadOSGradientStop], spread: RoadOSSpread = .pad)
    case radialGradient(center: CGPoint, radius: CGFloat, stops: [RoadOSGradientStop], spread: RoadOSSpread = .pad)

    public init(stringLiteral value: String) { self = .color(RoadOSColor(stringLiteral: value)) }

    func bridged(_ what: String) throws(RoadOSError) -> ROSPaint {
        let p = ROSPaint()
        func stops(_ s: [RoadOSGradientStop]) throws(RoadOSError) {
            p.stopOffsets = s.map { NSNumber(value: Float($0.offset)) }
            var colors: [NSNumber] = []
            for stop in s { colors.append(NSNumber(value: try stop.color.validated(what))) }
            p.stopColors = colors
        }
        switch self {
        case .color(let c):
            p.kind = 1
            p.argb = try c.validated(what)
        case let .linearGradient(from, to, s, spread):
            p.kind = 2
            p.x0 = Float(from.x); p.y0 = Float(from.y); p.x1 = Float(to.x); p.y1 = Float(to.y)
            p.spread = spread.rawValue
            try stops(s)
        case let .radialGradient(center, radius, s, spread):
            p.kind = 3
            p.x0 = Float(center.x); p.y0 = Float(center.y); p.radius = Float(radius)
            p.spread = spread.rawValue
            try stops(s)
        }
        return p
    }
}
