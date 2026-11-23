import Foundation
import RoadOSBridge

/// Severity levels of the RoadOS Visual Hazard Language (RVHL 1.0 proposal).
public enum HazardSeverity: Int, Sendable, CaseIterable, Hashable, Comparable {
    case informational = 1  // S1
    case low = 2            // S2 "Low caution"
    case moderate = 3       // S3 "Moderate caution"
    case high = 4           // S4 "High danger"
    case critical = 5       // S5 "Critical danger"

    /// "S1" … "S5"
    public var code: String { "S\(rawValue)" }
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public struct RoadOSFamily: Sendable, Hashable, Identifiable {
    public let id: String
    public let code: String
    public let label: String
    public let section: String
    public let description: String
}

/// One RVHL catalogue element, as defined by the Visual Hazard Studio.
public struct RoadOSEntry: Sendable, Hashable, Identifiable {
    /// Element ID, e.g. "RDM-003". The only unique identifier.
    public let id: String
    public let name: String
    /// e.g. "large_pothole". Not unique: a few slugs name both a sign and a geometry entry.
    public let slug: String
    public let family: String
    public let description: String
    /// Studio frame name, e.g. "roados_hazard" or "warning_triangle".
    public let frame: String
    public let standardFrame: String?
    public let variants: [String]
    public let defaultVariant: String?
    public let defaultSeverity: HazardSeverity
    /// Pictogram key, shared by related entries (e.g. "pothole").
    public let glyph: String
    public let tags: [String]

    init(_ e: ROSEntry) {
        id = e.identifier
        name = e.name
        slug = e.slug
        family = e.family
        description = e.entryDescription
        frame = e.frame
        standardFrame = e.standardFrame
        variants = e.variants
        defaultVariant = e.defaultVariant
        defaultSeverity = HazardSeverity(rawValue: e.defaultSeverity) ?? .moderate
        glyph = e.glyph
        tags = e.tags
    }
}

/// The RVHL catalogue: 267 elements in 14 families, generated from the Visual
/// Hazard Studio and bundled with this package. Immutable and thread-safe.
public final class RoadOSCatalogue: @unchecked Sendable {
    // @unchecked: ROSLibrary wraps an immutable, internally synchronised C++
    // rvhl::Library; every stored property here is a `let`.
    let library: ROSLibrary
    public let entries: [RoadOSEntry]
    public let families: [RoadOSFamily]
    private let byId: [String: RoadOSEntry]

    /// Loads an RVHL bundle directory (manifest.json, catalogue.json, tokens.json,
    /// pictograms/). Bundle hashes are verified. Loads are cached per path.
    public init(contentsOf directory: URL) throws(RoadOSError) {
        library = try bridged { try ROSLibrary(path: directory.path) }
        entries = library.entries.map(RoadOSEntry.init)
        families = library.families.map {
            RoadOSFamily(id: $0.identifier, code: $0.code, label: $0.label, section: $0.section,
                         description: $0.familyDescription)
        }
        byId = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    private static let bundledResult: Result<RoadOSCatalogue, RoadOSError> = {
        guard let url = Bundle.module.url(forResource: "rvhl", withExtension: nil) else {
            return .failure(RoadOSError(.notFound,
                "RVHL bundle missing from package resources; run scripts/build_xcframework.sh"))
        }
        do throws(RoadOSError) {
            return .success(try RoadOSCatalogue(contentsOf: url))
        } catch {
            return .failure(error)
        }
    }()

    /// The catalogue bundled with the SDK (loaded once).
    public static func bundled() throws(RoadOSError) -> RoadOSCatalogue {
        try bundledResult.get()
    }

    /// `catalogue`'s library, or the bundled one when nil.
    static func resolve(_ catalogue: RoadOSCatalogue?) throws(RoadOSError) -> ROSLibrary {
        if let catalogue { return catalogue.library }
        return try bundled().library
    }

    public var rvhlVersion: String { library.rvhlVersion }
    /// Visual Hazard Studio commit the bundle was generated from.
    public var studioCommit: String { library.studioCommit }

    /// Looks up an entry by element ID ("RDM-003", case-insensitive) or by an
    /// unambiguous slug ("large_pothole"). For glyph keys such as "pothole" or
    /// shared slugs the error lists the candidate IDs.
    public func entry(_ idOrSlug: String) throws(RoadOSError) -> RoadOSEntry {
        let e = try bridged { try library.lookupEntry(idOrSlug) }
        return byId[e.identifier]!
    }

    public func entries(inFamily familyId: String) -> [RoadOSEntry] {
        entries.filter { $0.family == familyId }
    }

    /// Entries drawn with a pictogram key, e.g. "pothole" → 9 entries.
    public func entries(withGlyph glyph: String) -> [RoadOSEntry] {
        entries.filter { $0.glyph == glyph }
    }
}
