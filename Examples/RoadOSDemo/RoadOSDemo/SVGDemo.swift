import RoadOSGraphics
import SwiftUI

/// Live SVG rendering through Skia's SVG module in the shared core.
struct SVGDemo: View {
    @State private var markup = Self.sample
    @State private var image: CGImage?
    @State private var error: String?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        Checkerboard()
                        if let image {
                            Image(decorative: image, scale: displayScale).resizable().scaledToFit()
                        }
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                    if let error {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                Section("SVG markup") {
                    TextEditor(text: $markup)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 220)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("SVG rendering")
            .task(id: markup) { await render() }
        }
    }

    private func render() async {
        let g = RoadOSGraphics(width: 220, height: 220)
        g.svg { $0.markup = markup; $0.width = 220; $0.height = 220 }
        do {
            image = try await g.renderAsync(scale: displayScale)
            error = nil
        } catch {
            self.error = error.message
        }
    }

    static let sample = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <defs>
        <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#2196F3"/>
          <stop offset="1" stop-color="#00BCD4"/>
        </linearGradient>
      </defs>
      <rect x="6" y="6" width="88" height="88" rx="18" fill="url(#g)"/>
      <path d="M30 70 L50 26 L70 70 Z" fill="none" stroke="#FFFFFF"
            stroke-width="6" stroke-linejoin="round"/>
      <circle cx="50" cy="58" r="4" fill="#FFFFFF"/>
    </svg>
    """
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 12
            for y in stride(from: 0, to: size.height, by: s) {
                for x in stride(from: 0, to: size.width, by: s) where (Int(x / s) + Int(y / s)).isMultiple(of: 2) {
                    ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(.gray.opacity(0.15)))
                }
            }
        }
    }
}
