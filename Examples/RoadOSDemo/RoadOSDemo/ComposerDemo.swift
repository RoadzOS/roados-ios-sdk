import RoadOSGraphics
import SwiftUI
import UIKit

/// Hazard composition: severity, representation, badges and layers, shown in
/// SwiftUI (RoadOSIcon) and UIKit (RoadOSHazardView) side by side.
struct ComposerDemo: View {
    let entryId: String
    @State private var hazard: RoadOSHazard
    @State private var speedKind = 0
    @State private var hiddenLayers: Set<HazardLayer> = []
    @State private var showSVG = false

    init(entryId: String) {
        self.entryId = entryId
        _hazard = State(initialValue: RoadOSHazard(entryId))
    }

    private var entry: RoadOSEntry? { try? RoadOSCatalogue.bundled().entry(entryId) }

    private var composed: RoadOSHazard {
        var h = hazard
        switch speedKind {
        case 1: h.speed = .posted(kmh: 50)
        case 2: h.speed = .advisory(kmh: 30)
        case 3: h.speed = .unknown
        default: h.speed = nil
        }
        if !hiddenLayers.isEmpty { h.layers = HazardLayer.allCases.filter { !hiddenLayers.contains($0) } }
        return h
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 24) {
                    VStack {
                        RoadOSIcon(composed).frame(width: 128, height: 128)
                        Text("SwiftUI").font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack {
                        HazardUIView(hazard: composed).frame(width: 96, height: 96).frame(height: 128)
                        Text("UIKit").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            } footer: {
                if let entry { Text("\(entry.id) · \(entry.description)") }
            }

            Section("Severity") {
                Picker("Severity", selection: $hazard.severity) {
                    Text("Default").tag(HazardSeverity?.none)
                    ForEach(HazardSeverity.allCases, id: \.self) { Text($0.code).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
                Picker("Theme", selection: $hazard.theme) {
                    Text("Dark").tag(RoadOSTheme.dark)
                    Text("Light").tag(RoadOSTheme.light)
                }
                Picker("Representation", selection: $hazard.representation) {
                    Text("Auto").tag(HazardRepresentation.auto)
                    Text("Standard").tag(HazardRepresentation.standard)
                    Text("RoadOS").tag(HazardRepresentation.roados)
                }
                if let variants = entry?.variants, !variants.isEmpty {
                    Picker("Variant", selection: $hazard.variant) {
                        Text("Default").tag(String?.none)
                        ForEach(variants, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                }
            }

            Section("Badges") {
                Picker("Speed", selection: $speedKind) {
                    Text("None").tag(0); Text("Posted 50").tag(1); Text("Advisory 30").tag(2); Text("Unknown").tag(3)
                }
                Toggle("Distance", isOn: Binding(get: { hazard.distanceMeters != nil },
                                                 set: { hazard.distanceMeters = $0 ? 150 : nil }))
                if let d = hazard.distanceMeters {
                    Slider(value: Binding(get: { d }, set: { hazard.distanceMeters = $0 }), in: 0...3000, step: 10)
                }
                Stepper("Count: \(hazard.count ?? 1)", value: Binding(get: { hazard.count ?? 1 },
                                                                      set: { hazard.count = $0 > 1 ? $0 : nil }), in: 1...9)
                Picker("Direction", selection: $hazard.direction) {
                    Text("None").tag(HazardDirection?.none)
                    Text("Left").tag(HazardDirection?.some(.left))
                    Text("Ahead").tag(HazardDirection?.some(.ahead))
                    Text("Right").tag(HazardDirection?.some(.right))
                    Text("Both").tag(HazardDirection?.some(.both))
                }
                Toggle("Severity code", isOn: $hazard.showSeverityCode)
            }

            Section("Layers") {
                ForEach(HazardLayer.allCases, id: \.self) { layer in
                    Toggle(String(describing: layer), isOn: Binding(
                        get: { !hiddenLayers.contains(layer) },
                        set: { if $0 { hiddenLayers.remove(layer) } else { hiddenLayers.insert(layer) } }))
                }
            }

            Section {
                DisclosureGroup("Composed SVG", isExpanded: $showSVG) {
                    Text((try? composed.svg()) ?? "—")
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(entry?.name ?? entryId)
    }
}

/// Wraps the SDK's UIKit view for use in SwiftUI.
private struct HazardUIView: UIViewRepresentable {
    let hazard: RoadOSHazard
    func makeUIView(context: Context) -> RoadOSHazardView { RoadOSHazardView(hazard: hazard) }
    func updateUIView(_ view: RoadOSHazardView, context: Context) { view.hazard = hazard }
}
