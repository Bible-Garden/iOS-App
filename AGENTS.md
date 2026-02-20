# Repository Guidelines

## Project Structure & Module Organization
`BibleGarden.xcodeproj` is the iOS project entry point. The app code lives in `Bible/`:
- `BibleGardenApp.swift`, `SkeletonView.swift`, and `MenuView.swift` define app startup and primary navigation.
- `Pages/` contains screen-level SwiftUI views (for example, `PageReadView.swift` and `PageMultilingualReadView.swift`).
- `Models/` contains data models and API-facing types.
- `Adv/` contains shared audio/UI utilities (legacy `adv*` filenames are expected).
- `Assets.xcassets` and `{en,ru,uk}.lproj/Localizable.strings` store visual and localization assets.

UI tests live in `BibleGardenUITests/` with shared helpers in `BibleGardenUITests/Helpers/`. API spec/generation inputs live in `Bible/openapi.yaml` and `Bible/openapi-generator-config.yml`.

## Build, Test, and Development Commands
- `cp Bible/Debug.xcconfig.example Bible/Debug.xcconfig && cp Bible/Release.xcconfig.example Bible/Release.xcconfig`
  Creates required local API config files (do this once per machine).
- `open BibleGarden.xcodeproj`
  Opens the project in Xcode for local development.
- `xcodebuild -project BibleGarden.xcodeproj -scheme BibleGarden -configuration Debug CODE_SIGNING_ALLOWED=NO build`
  Runs a CLI debug build without code signing.
- `xcodebuild test -project BibleGarden.xcodeproj -scheme BibleGarden -testPlan BibleGarden -destination 'platform=iOS Simulator,name=iPhone 16'`
  Runs UI tests from the test plan.

## Coding Style & Naming Conventions
Use Swift 5/SwiftUI conventions: 4-space indentation, no tabs, and `// MARK:` separators in larger files. Use `UpperCamelCase` for types and views, `lowerCamelCase` for properties/functions, and descriptive enum cases. Keep screen files as `Page*View.swift`; keep existing `adv*` naming in shared legacy modules. Prefer `.accessibilityIdentifier("...")` for interactive UI to keep tests stable.

## Testing Guidelines
This repository currently uses UI tests (`BibleGardenUITests`) rather than unit tests. Keep one feature area per `XCTestCase` file (for example, `MenuTests.swift`) and test names in `test...` form. Reuse helpers from `XCUIApplication+Helpers.swift` and prefer accessibility-identifier lookups over visible text.

## Commit & Pull Request Guidelines
Recent history favors short, imperative commit subjects (examples: `fix readme`, `Rename pages`, `menu tests`). Keep commits focused and include related test updates when behavior changes. PRs should include a concise summary, linked issue (if any), test evidence, and screenshots/video for UI changes. Never commit secrets or local config files such as `Bible/Debug.xcconfig`, `Bible/Release.xcconfig`, or `Bible/Configuration.plist`.
