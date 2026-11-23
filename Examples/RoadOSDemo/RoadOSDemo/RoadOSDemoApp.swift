import RoadOSGraphics
import SwiftUI

@main
struct RoadOSDemoApp: App {
    enum Tab: String { case graphics, svg, hazards, composer }

    // `-initialTab hazards` on launch (e.g. `simctl launch … -initialTab hazards`) opens that tab.
    @State private var tab = Tab(rawValue: UserDefaults.standard.string(forKey: "initialTab") ?? "") ?? .graphics

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                GraphicsDemo()
                    .tabItem { Label("Graphics", systemImage: "scribble.variable") }
                    .tag(Tab.graphics)
                SVGDemo()
                    .tabItem { Label("SVG", systemImage: "chevron.left.forwardslash.chevron.right") }
                    .tag(Tab.svg)
                CatalogueDemo()
                    .tabItem { Label("Hazards", systemImage: "exclamationmark.triangle") }
                    .tag(Tab.hazards)
                NavigationStack { ComposerDemo(entryId: "RDM-003") }
                    .tabItem { Label("Composer", systemImage: "slider.horizontal.3") }
                    .tag(Tab.composer)
            }
        }
    }
}
