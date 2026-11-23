import CoreGraphics
import RoadOSBridge

public enum RoadOSTheme: Int, Sendable, Hashable, CaseIterable { case dark = 0, light = 1 }

public enum HazardRepresentation: Int, Sendable, Hashable {
    /// The entry's own frame.
    case auto = 0
    /// Its road-sign convention frame, when it has one.
    case standard = 1
    /// Always a RoadOS tile.
    case roados = 2
}

public enum HazardSizeVariant: Int, Sendable, Hashable { case s = 0, m, l, xl }
public enum HazardDirection: Int, Sendable, Hashable { case left = 0, ahead, right, both }
public enum RoadOSSpeedUnit: Int, Sendable, Hashable { case kmh = 0, mph = 1 }
public enum RoadOSUnitSystem: Int, Sendable, Hashable { case metric = 0, imperial = 1 }

/// Speed badge. Values are always given in km/h and converted for display.
/// Advisory speeds are RoadOS proposals and never legal limits.
public enum HazardSpeedBadge: Sendable, Hashable {
    case posted(kmh: Double, unit: RoadOSSpeedUnit = .kmh)
    case advisory(kmh: Double, unit: RoadOSSpeedUnit = .kmh)
    case unknown
}

public struct HazardLane: Sendable, Hashable {
    public var count: Int
    public var index: Int
    public init(count: Int, index: Int) {
        self.count = count
        self.index = index
    }
}

/// Composition layers in their default paint order.
public enum HazardLayer: Int, Sendable, Hashable, CaseIterable {
    case background = 0, frame, pictogram, slash, severityCode, severityBar, lane, direction, count, sizeChip, speed,
         distance
}

/// A RoadOS hazard icon: an RVHL catalogue entry plus composition options.
/// Composition and rendering run in the shared C++ core, producing the same
/// result as the Visual Hazard Studio and the Android SDK.
///
///     let hazard = RoadOSHazard.create("RDM-003") {
///         $0.severity = .high
///         $0.size = 128
///         $0.theme = .dark
///     }
///     let image = try hazard.render(scale: 2)
public struct RoadOSHazard: Sendable, Hashable {
    /// Element ID ("RDM-003") or unambiguous slug ("large_pothole").
    public var id: String
    public var variant: String?
    /// nil = the entry's default severity.
    public var severity: HazardSeverity?
    public var theme: RoadOSTheme = .dark
    public var representation: HazardRepresentation = .auto
    /// Icon size in points (square). Multiply by `scale` at render time for pixels.
    public var size: Int = 128
    public var count: Int?
    public var speed: HazardSpeedBadge?
    public var distanceMeters: Double?
    public var unitSystem: RoadOSUnitSystem = .metric
    public var direction: HazardDirection?
    public var lane: HazardLane?
    public var sizeVariant: HazardSizeVariant?
    public var showSeverityCode = true
    public var background: RoadOSColor?
    /// Paint order; nil = default. Layers left out are not drawn.
    public var layers: [HazardLayer]?

    public init(_ id: String) { self.id = id }

    public static func create(_ id: String, _ configure: (inout RoadOSHazard) -> Void = { _ in }) -> RoadOSHazard {
        var h = RoadOSHazard(id)
        configure(&h)
        return h
    }

    func spec(size override: CGSize? = nil) throws(RoadOSError) -> ROSHazardSpec {
        let s = ROSHazardSpec()
        s.identifier = id
        s.variant = variant ?? ""
        s.severity = severity?.rawValue ?? 0
        s.theme = theme.rawValue
        s.representation = representation.rawValue
        s.sizeVariant = sizeVariant?.rawValue ?? -1
        s.count = count ?? 0
        switch speed {
        case nil: s.speedKind = -1
        case let .posted(kmh, unit)?: s.speedKind = 0; s.speedKmh = kmh; s.speedUnit = unit.rawValue
        case let .advisory(kmh, unit)?: s.speedKind = 1; s.speedKmh = kmh; s.speedUnit = unit.rawValue
        case .unknown?: s.speedKind = 2
        }
        s.distanceMeters = distanceMeters ?? -1
        s.unitSystem = unitSystem.rawValue
        s.direction = direction?.rawValue ?? -1
        if let lane {
            s.laneCount = lane.count
            s.laneIndex = lane.index
        }
        s.showSeverityCode = showSeverityCode
        if let background {
            s.hasBackground = true
            s.backgroundARGB = try background.validated("background")
        }
        s.layers = (layers ?? []).map { NSNumber(value: $0.rawValue) }
        if layers?.isEmpty == true {
            // An explicitly empty list means "draw nothing", not "default order".
            throw RoadOSError(.invalidArgument, "layers must not be empty; use nil for the default order")
        }
        s.width = override.map { Int($0.width) } ?? size
        s.height = override.map { Int($0.height) } ?? size
        return s
    }

    /// Renders at `size × scale` pixels with the shared C++ engine.
    public func render(scale: CGFloat = 1, catalogue: RoadOSCatalogue? = nil) throws(RoadOSError) -> CGImage {
        let lib = try RoadOSCatalogue.resolve(catalogue)
        let spec = try spec()
        return try bridged { try lib.renderHazard(spec, scale: scale) }
    }

    /// Renders off the calling actor.
    public func renderAsync(scale: CGFloat = 1, catalogue: RoadOSCatalogue? = nil) async throws(RoadOSError) -> CGImage {
        let hazard = self
        let result = await Task.detached(priority: .userInitiated) { () -> Result<CGImage, RoadOSError> in
            do throws(RoadOSError) {
                return .success(try hazard.render(scale: scale, catalogue: catalogue))
            } catch {
                return .failure(error)
            }
        }.value
        return try result.get()
    }

    /// The composed icon as SVG markup (the Studio's 128×128 format).
    public func svg(catalogue: RoadOSCatalogue? = nil) throws(RoadOSError) -> String {
        let lib = try RoadOSCatalogue.resolve(catalogue)
        let spec = try spec()
        return try bridged { try lib.svg(forHazard: spec) }
    }
}
