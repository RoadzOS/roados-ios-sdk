#if canImport(UIKit)
import UIKit

public extension RoadOSGraphics {
    /// Renders the scene as a UIImage at `scale` (default: the current trait
    /// collection's display scale).
    func renderImage(scale: CGFloat? = nil) throws(RoadOSError) -> UIImage {
        let s = scale ?? UITraitCollection.current.displayScale
        return UIImage(cgImage: try render(scale: s), scale: s, orientation: .up)
    }

    /// Renders an RVHL hazard icon as a UIImage.
    ///
    ///     imageView.image = try RoadOSGraphics.render(hazard: "RDM-003",
    ///                                                 size: CGSize(width: 128, height: 128))
    static func render(hazard id: String, size: CGSize, severity: HazardSeverity? = nil,
                       theme: RoadOSTheme = .dark, scale: CGFloat? = nil,
                       catalogue: RoadOSCatalogue? = nil) throws(RoadOSError) -> UIImage {
        var h = RoadOSHazard(id)
        h.severity = severity
        h.theme = theme
        h.size = Int(min(size.width, size.height).rounded())
        return try h.image(scale: scale, catalogue: catalogue)
    }
}

public extension RoadOSHazard {
    /// Renders the icon as a UIImage of `size` points at `scale`.
    func image(scale: CGFloat? = nil, catalogue: RoadOSCatalogue? = nil) throws(RoadOSError) -> UIImage {
        let s = scale ?? UITraitCollection.current.displayScale
        return UIImage(cgImage: try render(scale: s, catalogue: catalogue), scale: s, orientation: .up)
    }
}

/// UIKit view that shows a RoadOS hazard icon, re-rendered off the main thread
/// whenever the hazard, bounds or display scale changes.
@MainActor
public final class RoadOSHazardView: UIImageView {
    public var hazard: RoadOSHazard? {
        didSet { if hazard != oldValue { scheduleRender() } }
    }
    public var catalogue: RoadOSCatalogue? {
        didSet { scheduleRender() }
    }
    /// Called with any rendering error (the image is cleared).
    public var onError: ((RoadOSError) -> Void)?

    private var renderTask: Task<Void, Never>?
    private var lastKey: (RoadOSHazard, Int, CGFloat)?

    public convenience init(hazard: RoadOSHazard) {
        self.init(frame: CGRect(x: 0, y: 0, width: hazard.size, height: hazard.size))
        self.hazard = hazard
        contentMode = .scaleAspectFit
        isAccessibilityElement = true
        scheduleRender()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        scheduleRender()
    }

    override public func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        scheduleRender()
    }

    private func scheduleRender() {
        guard var h = hazard, bounds.width > 0, bounds.height > 0 else { return }
        let points = Int(min(bounds.width, bounds.height).rounded())
        let scale = traitCollection.displayScale
        if let k = lastKey, k.0 == h, k.1 == points, k.2 == scale { return }
        lastKey = (h, points, scale)
        h.size = points
        accessibilityLabel = (try? (catalogue ?? RoadOSCatalogue.bundled()).entry(h.id).name) ?? h.id
        renderTask?.cancel()
        let catalogue = self.catalogue
        renderTask = Task { [weak self] in
            do {
                let cg = try await h.renderAsync(scale: scale, catalogue: catalogue)
                guard !Task.isCancelled else { return }
                self?.image = UIImage(cgImage: cg, scale: scale, orientation: .up)
            } catch {
                guard !Task.isCancelled else { return }
                self?.image = nil
                self?.onError?(RoadOSError(error))
            }
        }
    }
}
#endif
