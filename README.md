# RoadOS iOS SDK

Native iOS bindings for [RoadOS Graphics Core](https://github.com/RoadzOS/roados-graphics-core), the shared C++20 / Skia rendering engine behind RoadzOS.

> **Status: not implemented yet.** This repository has been created ahead of development. It contains no Swift code yet, and nothing is published to any package registry. Work starts once the Graphics Core public API is frozen (catalogue + hazard composition phases).

## Planned scope

* **Swift 6 API:** `RoadOSGraphics` for general vector graphics (shapes, paths, gradients, text, images, SVG) and `RoadOSHazard` for RVHL hazard pictograms and compositions.
* **SwiftUI:** a `RoadOSIcon` view.
* **UIKit:** rendering to `UIImage` and `CGImage`.
* **Async rendering** that is compatible with Swift concurrency.
* **Error handling** through Swift `throws`, mapped from the core's `Result<T>`. No C++ exceptions cross the bridge.

## Architecture

```
RoadOS Visual Hazard Studio  (canonical catalogue + pictograms, web)
          │ generated, hashed RVHL bundle
          ▼
RoadOS Graphics Core          (C++20 / Skia, the only renderer)
          │ static libraries, built per Apple platform
          ▼
roados-ios-sdk
  ├─ Objective-C++ bridge     (thin; no rendering logic)
  └─ Swift API, SwiftUI, UIKit
```

All drawing happens in the C++ core. This SDK does not re-implement any rendering in Swift, and it does not copy the RVHL catalogue.

## Planned layout

```
Package.swift
Sources/
  RoadOSGraphicsBridge/   Objective-C++ wrapper over the core's public C++ API
  RoadOSGraphics/         Swift API, SwiftUI and UIKit integrations
Binaries/                 RoadOSCore.xcframework (built by script, not committed)
scripts/                  build_xcframework.sh: Skia + core for iOS device and simulator
Tests/
Examples/RoadOSDemo/      sample iOS app
```

## Build requirements (planned)

* Xcode 16 or newer (Swift 6)
* iOS 17+ deployment target
* CMake ≥ 3.24 and Python 3 (to build Skia and the core)

## Related repositories

| Repository | Role |
|---|---|
| [roados-visual-hazard-studio](https://github.com/RoadzOS/roados-visual-hazard-studio) | Web studio. It is the canonical source of the RVHL catalogue and pictograms. |
| [roados-graphics-core](https://github.com/RoadzOS/roados-graphics-core) | C++ / Skia engine. It is the canonical renderer. |
| roados-android-sdk | Kotlin / JNI bindings (not created yet) |

## License

No license has been chosen yet.
