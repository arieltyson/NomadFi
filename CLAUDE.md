# NomadFi — Claude Code Instructions

## Role

Senior iOS Engineer specializing in SwiftUI, Vision, Core ML, AVFoundation (TTS & Audio Session), Core Haptics, Observation Framework (State Management), App Intents + Shortcuts (Siri Integration), Accessibility (VoiceOver & Dynamic Type), Swift 6.2, Swift Concurrency (async/await, actors, strict concurrency), Swift Testing + XCTest UI Testing, SwiftData, FinanceKit, VisionKit (DataScannerViewController), Vision (Text Recognition), CoreLocation, ActivityKit + WidgetKit (Live Activities & Widgets), Charts, TipKit, UserNotifications, StoreKit, OSLog (Structured Logging), and related frameworks.

All code must adhere to Apple's Human Interface Guidelines and App Review Guidelines.

## Implementation Strategy

- Follow MVVM architectural design pattern with Clean Architecture and SOLID principles.
- Implement everything optimally using the most modern and up-to-date iOS development best practices.
- Follow the latest official Apple documentation in accordance with the latest versions of the Swift programming language, iOS, Xcode, and SwiftUI.
- Demonstrate high-quality code that is both Swifty and idiomatic.

## Design Standards

The app must simultaneously target an Apple Design Award and follow the Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines

Focus on the key features that allowed winners to be featured in each category, especially **Innovation** and **Social Impact**: https://developer.apple.com/design/awards/

## Core Constraints

- **Target:** iOS 26.0 or later
- **Language:** Swift 6.2 or later, using modern Swift concurrency
- **UI:** SwiftUI backed by `@Observable` classes for shared data
- **No third-party frameworks** without asking first
- **Avoid UIKit** unless explicitly requested

## Swift Rules

- Always mark `@Observable` classes with `@MainActor`.
- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist (e.g., `replacing("hello", with: "world")` instead of `replacingOccurrences(of:with:)`).
- Prefer modern Foundation API (e.g., `URL.documentsDirectory`, `appending(path:)` for URL strings).
- Never use C-style number formatting such as `Text(String(format: "%.2f", abs(myNumber)))` — always use `Text(abs(change), format: .number.precision(.fractionLength(2)))`.
- Prefer static member lookup over struct instances (e.g., `.circle` instead of `Circle()`, `.borderedProminent` instead of `BorderedProminentButtonStyle()`).
- Never use old-style Grand Central Dispatch (`DispatchQueue.main.async()`). Always use modern Swift concurrency.
- Filter text based on user input with `localizedStandardContains()`, not `contains()`.
- Avoid force unwraps and force try unless the failure is unrecoverable.

## SwiftUI Rules

- Use `foregroundStyle()` instead of `foregroundColor()`.
- Use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`.
- Use the `Tab` API instead of `tabItem()`.
- Never use `ObservableObject` — always prefer `@Observable` classes.
- Never use the `onChange()` modifier in its 1-parameter variant; use the variant that accepts two parameters or none.
- Never use `onTapGesture()` unless you need the tap location or tap count. Use `Button` for all other cases.
- Never use `Task.sleep(nanoseconds:)` — always use `Task.sleep(for:)`.
- Never use `UIScreen.main.bounds` to read available space.
- Do not break views up using computed properties — extract into new `View` structs.
- Do not force specific font sizes — prefer Dynamic Type.
- Use `navigationDestination(for:)` and always use `NavigationStack` instead of `NavigationView`.
- Button labels with images must include text: `Button("Tap me", systemImage: "plus", action: myButtonAction)`.
- Prefer `ImageRenderer` over `UIGraphicsImageRenderer` for rendering SwiftUI views.
- Do not apply `fontWeight()` without good reason. Use `bold()` instead of `fontWeight(.bold)`.
- Do not use `GeometryReader` if a newer alternative works (e.g., `containerRelativeFrame()`, `visualEffect()`).
- For `ForEach` with an enumerated sequence, do not convert to an array: `ForEach(x.enumerated(), id: \.element.id)`.
- Hide scroll indicators with `.scrollIndicators(.hidden)` instead of `showsIndicators: false`.
- Place view logic into view models or similar so it can be tested.
- Avoid `AnyView` unless absolutely required.
- Avoid hard-coded values for padding and stack spacing unless requested.
- Avoid UIKit colors in SwiftUI code.
- `'+'` was deprecated in iOS 26.0 for `Text` concatenation — use string interpolation: `Text("Hello \(name)")`.

## SwiftData Rules

If SwiftData is configured to use CloudKit:

- Never use `@Attribute(.unique)`.
- Model properties must always either have default values or be marked as optional.
- All relationships must be marked optional.

## Project Structure

- Use a consistent project structure with folder layout determined by app features.
- Follow strict naming conventions for types, properties, methods, and SwiftData models.
- Break different types into separate Swift files rather than placing multiple structs, classes, or enums in a single file.
- Add code comments and documentation comments as needed.
- Never include secrets such as API keys in the repository.
