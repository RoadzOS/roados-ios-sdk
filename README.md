# RoadOS iOS SDK

Swift 6 / SwiftUI / UIKit bindings for [RoadOS Graphics Core](https://github.com/RoadzOS/roados-graphics-core), the C++20 + Skia engine that RoadzOS shares across platforms. All drawing, SVG rendering, RVHL catalogue access and hazard composition run in that engine, the same one the Android SDK uses. This package adds no rendering logic of its own.

```swift
import RoadOSGraphics

// General-purpose vector graphics
let graphics = RoadOSGraphics.create {
    $0.width = 512
    $0.height = 512
    $0.background = .transparent
}
graphics.circle {
    $0.centerX = 100
    $0.centerY = 100
    $0.radius = 40
    $0.fill = "#2196F3"
}
let image = try graphics.render(scale: 2)  // CGImage, 1024×1024

// RoadOS hazard icons from the Visual Hazard Studio catalogue
let hazard = RoadOSHazard.create("RDM-003") {  // Large pothole
    $0.severity = .high                          // S4
    $0.size = 128
    $0.theme = .dark
    $0.distanceMeters = 150
}
let icon = try hazard.render(scale: 3)
```

```swift
// SwiftUI
RoadOSIcon(hazardId: "RDM-003", severity: .high)
    .frame(width: 64, height: 64)

// UIKit
imageView.image = try RoadOSGraphics.render(hazard: "RDM-003", size: CGSize(width: 128, height: 128))
let view = RoadOSHazardView(hazard: RoadOSHazard("SIG-002"))
```

> **Hazard identifiers.** Look hazards up by **element ID** (`"RDM-003"`) or by an unambiguous slug (`"large_pothole"`). `"pothole"` is a *pictogram key* that 9 catalogue entries share. Looking it up throws `RoadOSError.notFound` with a message that lists the candidate IDs. Some slugs, such as `hairpin_bend` (`RSG-015` and `GEO-004`), are also shared by more than one entry.

## Status

**Version 0.1.0. Not yet published.** Nothing has been released to a package registry, and the prebuilt binary is not committed. Use the package from a local checkout, as described below.

Verified on macOS 27.2 (Apple silicon) with Xcode 27.2 (Swift 6.4):

| Check | Result |
|---|---|
| `swift test` (macOS, arm64) | 16 / 16 pass |
| `xcodebuild test`, iPhone 15 Pro Simulator, iOS 17.2 | 16 / 16 pass |
| Sample app build and run (iOS 17.2 Simulator) | builds and runs. The Graphics, SVG, Hazards and Composer screens were screenshotted |
| Physical iOS device | **not tested** (the `ios-arm64` slice builds and links) |

## Installation (local)

Requirements: Xcode 16 or later (Swift 6), CMake 3.24 or later, Python 3, git, and about 600 MB of disk space for Skia sources and builds. Supported targets: iOS 17+ devices, iOS Simulator on **Apple-silicon** Macs, and macOS 14+ on Apple silicon (for tests).

```bash
git clone --recurse-submodules https://github.com/RoadzOS/roados-ios-sdk.git
cd roados-ios-sdk
scripts/build_xcframework.sh   # builds Skia + the core → Binaries/RoadOSCore.xcframework
swift test                      # optional
```

Then in Xcode, choose **File ▸ Add Package Dependencies ▸ Add Local…** and select this folder. Alternatively, reference it from another package:

```swift
.package(path: "../roados-ios-sdk")
```

To reuse a Skia checkout that already exists (for example, the core repository's), set `ROADOS_SKIA_DIR=/path/to/skia`.

## Sample app

`Examples/RoadOSDemo` is a SwiftUI app with four screens:

* **Graphics:** custom vector graphics with gradients, Bézier paths, a polygon, dashed lines, text, and a rotated group. An RVHL hazard is composed into the same scene.
* **SVG:** live SVG rendering through Skia's SVG module, with editable markup.
* **Hazards:** all 267 catalogue entries grouped by family, rendered live in dark or light theme, with search.
* **Composer:** severity, representation, variant, speed, distance, count and direction badges, and per-layer toggles. Each change is shown side by side in SwiftUI (`RoadOSIcon`) and UIKit (`RoadOSHazardView`), and the composed SVG is displayed.

```bash
scripts/build_xcframework.sh
open Examples/RoadOSDemo/RoadOSDemo.xcodeproj    # run on an iOS 17+ simulator or device
```

The project is generated from `Examples/RoadOSDemo/project.yml` with XcodeGen. The generated project is committed.

## API overview

| Type | Purpose |
|---|---|
| `RoadOSGraphics` | Scene builder. Shapes include `circle`, `ellipse`, `rect`/`roundedRect`, `line`, `polyline`, `polygon`, `path` (SVG path data with cubic and quadratic Béziers), `text`, `svg`, `image(CGImage)`, `hazard`, and `group(transform:opacity:clip:)`. Output: `render(scale:)`, `renderAsync(scale:)`, `svgString()`, and `renderImage()` on UIKit. |
| `RoadOSStyle` / shape specs | Fill and stroke `RoadOSPaint`: a colour, or a linear or radial gradient with stops and a spread mode. Also stroke width, cap, join, dash, opacity, blend mode, and transform, with the helpers `rotate`, `scale` and `translate`. |
| `RoadOSColor` | Hex colours, parsed by the core's parser. String literals work: `$0.fill = "#2196F3"`. |
| `RoadOSCatalogue` | The bundled RVHL catalogue (267 entries, 14 families). Lookup by ID or slug. The bundle's hashes are verified when it loads. |
| `RoadOSHazard` | Entry plus composition options: severity, theme, representation, variant, speed, distance, count, direction, lane, size chip, background, layer order. `render`, `renderAsync`, `svg`. |
| `RoadOSIcon` (SwiftUI), `RoadOSCanvas` (SwiftUI) | Render asynchronously at the view's size and the display scale. |
| `RoadOSHazardView` (UIKit) | A `UIImageView` that re-renders when the hazard, bounds or traits change. |
| `RoadOSError` | Typed errors whose codes mirror the core's `ErrorCode`. |

**Errors.** Drawing calls never throw. The first invalid input (a bad colour literal, malformed path data, a negative radius) is stored in `firstError` and thrown by `render()`. Nothing is clamped or ignored silently.

**Threading.**
* `RoadOSGraphics` is not thread-safe while you build a scene.
* `renderAsync` snapshots the scene on the caller's actor and renders the copy in the background.
* `RoadOSHazard`, `RoadOSColor` and the shape specs are `Sendable` values.
* `RoadOSCatalogue` is immutable and `Sendable`.

## Architecture

```
Visual Hazard Studio (web, canonical catalogue)
        │  generated, hashed RVHL bundle (assets/rvhl in the core)
        ▼
RoadOS Graphics Core (C++20 / Skia)          external/roados-graphics-core (submodule)
  roados_graphics · roados_rvhl · roados_binding
        │  scripts/build_xcframework.sh
        ▼
Binaries/RoadOSCore.xcframework  (static lib + C++ headers; macOS, iOS, iOS Simulator arm64)
        │
Sources/RoadOSBridge   Objective-C++: Objective-C values → roados::binding specs (marshalling only)
        │
Sources/RoadOSGraphics Swift API, SwiftUI, UIKit; RVHL bundle as package resources
```

The Android SDK calls the same `roados::binding` facade through JNI, so both platforms share one implementation of styles, scenes, hazard options and catalogue caching.

## Known limitations

* **No Intel slices.** The xcframework contains arm64 only, so the iOS Simulator on Intel Macs is not supported.
* **Text varies by platform.** Text renders with the platform's fonts through CoreText. RVHL labels request `Inter` and fall back to the system sans-serif. See the core's visual-regression tolerances.
* **Priority-inversion diagnostic.** Xcode's Thread Performance Checker reports a possible priority inversion when many icons render concurrently at user-initiated QoS. This happens because the core's caches use `std::mutex`. The tests pass, but the warning hasn't been fixed yet.
* **Severity API not exposed.** The core's severity and advisory-speed engine (`rvhl::computeSeverity`) is not exposed in Swift yet.

## Licensing

* **This repository:** no license has been chosen yet.
* **Skia:** BSD-3-Clause. The core's other dependencies are listed in its README.
* **RVHL assets:** the core generates these from the Visual Hazard Studio, which currently declares "all rights reserved". Do not redistribute apps that bundle these assets until the Studio is licensed.

RVHL is a RoadOS proposal. It is not ISO-certified or officially approved.
