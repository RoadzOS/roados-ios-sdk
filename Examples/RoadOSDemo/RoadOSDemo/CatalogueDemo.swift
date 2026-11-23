import RoadOSGraphics
import SwiftUI

/// Every RVHL element inherited from the Visual Hazard Studio, by family.
struct CatalogueDemo: View {
    @State private var theme: RoadOSTheme = .dark
    @State private var search = ""
    private let catalogue = Result { try RoadOSCatalogue.bundled() }

    var body: some View {
        NavigationStack {
            switch catalogue {
            case .failure(let error):
                ContentUnavailableView("Catalogue unavailable", systemImage: "exclamationmark.triangle",
                                       description: Text("\(error.localizedDescription)"))
            case .success(let catalogue):
                List {
                    Section {
                        Picker("Theme", selection: $theme) {
                            Text("Dark").tag(RoadOSTheme.dark)
                            Text("Light").tag(RoadOSTheme.light)
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        Text("RVHL \(catalogue.rvhlVersion) · \(catalogue.entries.count) elements · Studio \(String(catalogue.studioCommit.prefix(7)))")
                    }
                    ForEach(catalogue.families) { family in
                        let entries = filtered(catalogue.entries(inFamily: family.id))
                        if !entries.isEmpty {
                            Section(family.label) {
                                ForEach(entries) { entry in
                                    NavigationLink(value: entry.id) { row(entry) }
                                }
                            }
                        }
                    }
                }
                .searchable(text: $search, prompt: "Name or ID")
                .navigationTitle("Hazards")
                .navigationDestination(for: String.self) { ComposerDemo(entryId: $0) }
            }
        }
    }

    private func filtered(_ entries: [RoadOSEntry]) -> [RoadOSEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search) }
    }

    private func row(_ entry: RoadOSEntry) -> some View {
        HStack(spacing: 12) {
            RoadOSIcon(hazardId: entry.id, theme: theme)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading) {
                Text(entry.name)
                Text("\(entry.id) · \(entry.defaultSeverity.code)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
