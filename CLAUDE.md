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
- `Material` (e.g., `.ultraThinMaterial`) is a `ShapeStyle`, not a `View` — it cannot be returned directly from a `@ViewBuilder`. Wrap it in a shape: `Rectangle().fill(.ultraThinMaterial)`.

## SwiftData Rules

- Always use fully qualified default values in `@Model` stored properties — the `@Model` macro cannot resolve shorthand static member syntax during expansion. Use `Date.now` instead of `.now`, `AccountType.checking` instead of `.checking`, etc.
- In bidirectional relationships, only declare `@Relationship(inverse:)` on **one** side — typically the to-many (parent) side. Leave the other side as a plain `var`. Declaring `inverse:` on both sides causes circular macro resolution errors.

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

---

# Project Description

## NomadFi — "Wealth without borders"

The "Ramp for Personal Finance" Operating System for International Students.

### Core Concept

**Ramp's Value Prop:** "Spend less, automate accounting, and get real-time visibility."
**NomadFi's Value Prop:** "Optimize cross-border wealth, automate tax compliance, and eliminate Forex waste."

Current personal finance apps (Mint, Copilot) are domestic-focused. They break when you add a Trinidadian bank account, a Canadian credit card, and a US J-1 salary. NomadFi acts as a "Personal CFO" that unifies these fragmented jurisdictions into one dashboard to prevent "financial leakage" (fees, poor exchange rates, forgotten subscriptions).

### Key Features (Mapped to Ramp)

**A. The "Universal Ledger" (Ramp Dashboard)**
Aggregates CIBC, Chase, and Wise to show Global Net Worth. Uses Apple's FinanceKit to pull transactions. Displays total net worth in all three currencies simultaneously (TTD, CAD, USD) using real-time mid-market rates.

**B. "Arbitrage Intelligence" (Ramp Savings Insights)**
Location-aware payment optimization. An "Active Card" widget that notifies: "Use Chase Freedom Rise. Do not use CIBC (2.5% FX fee)." Calculates the "Real Cost" of a purchase factoring in currency strength.

**C. The "Tax Vault" (Ramp Receipt Matching)**
Automates receipt collection for Non-Resident Alien (NRA) Tax Filing. Camera interface using Vision Framework (OCR) to read receipts, tag as "US Source" or "Canada Source," and save to iCloud. Exports a zip file for Sprintax or TurboTax.

**D. "Subscription Arbitrage" (Ramp Vendor Management)**
Detects cross-border subscription pricing differences and alerts: "Keep your Canadian subscription; it is 20% cheaper than switching to US pricing."

### Tech Stack

- **Language:** Swift 6 & SwiftUI
- **Data Persistence:** SwiftData (modern replacement for Core Data)
- **Hardware Integration:** Vision Framework (Text Recognition) for scanning receipts
- **System Integration:** App Intents (Siri Shortcuts)

### Market Justification

- **Financial Friction:** The affordability crisis for international students is driven by currency devaluation and tuition escalation, making precise money management a survival skill.
- **The "Superapp" Trend:** The financial industry is moving toward Embedded Finance and Superapps where services are seamlessly integrated rather than siloed by region or institution.
- **Automation Necessity:** Manual expense tracking is error-prone; automated categorization reduces administrative burden and increases visibility.

---

# Design Award Strategy

### Social Impact (Primary Target)
International students lose real money every day to hidden FX fees, tax confusion, and fragmented finances. NomadFi is a financial safety net for a vulnerable population navigating a foreign system.

### Innovation (Secondary Target)
Showcase novel use of Apple technologies — FinanceKit for on-device financial data, Vision Framework for receipt OCR, App Intents for Siri automation, and Liquid Glass for iOS 26's new design language.

### Inclusivity (Tertiary Alignment)
Every screen in NomadFi must be fully accessible from Day 1 — not bolted on at the end. Full VoiceOver + Dynamic Type support throughout.

---

# Implementation Plan — Commit-by-Commit Blueprint

## Phase 0 — Project Scaffold & Architecture (Commits 1–4)

### Commit 1: Xcode Project & Build Configuration
- Create the Xcode project targeting iOS 26.0+, Swift 6.2, with strict concurrency checking enabled
- Enable "Strict Concurrency Checking" -> Complete
- Enable Swift 6 language mode
- Configure bundle identifier, display name ("NomadFi"), app category (Finance)
- Add Liquid Glass app icon placeholder (clear-look style per iOS 26 HIG)
- Set up .gitignore, configure conventional commit messages

**Project structure:**
```
NomadFi/
├── App/
│   └── NomadFiApp.swift
├── Features/
│   ├── Dashboard/
│   ├── Ledger/
│   ├── Arbitrage/
│   ├── TaxVault/
│   ├── Subscriptions/
│   └── Onboarding/
├── Core/
│   ├── Models/
│   ├── Services/
│   ├── Extensions/
│   └── Utilities/
├── DesignSystem/
│   ├── Components/
│   ├── Tokens/
│   └── Theme/
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.xcstrings
└── Tests/
    ├── UnitTests/
    └── UITests/
```

### Commit 2: SwiftData Schema — The Financial Data Model
Define every persistent model before building any UI.

**Models:**
- `Account.swift` — Bank/card account across jurisdictions
- `Transaction.swift` — Individual financial transaction
- `Currency.swift` — Supported currency with metadata
- `ExchangeRate.swift` — Cached FX rate snapshots
- `TaxDocument.swift` — Receipt/document for tax vault
- `Subscription.swift` — Recurring subscription detected
- `Budget.swift` — Location-based budget
- `JurisdictionProfile.swift` — User's financial jurisdictions (TT, CA, US)

**Key design decisions:**
- All `@Model` classes get default values for every property (CloudKit compatibility)
- All relationships are optional (CloudKit requirement)
- No `@Attribute(.unique)` — use manual deduplication logic
- Use `CurrencyCode` as a lightweight enum/struct wrapping ISO 4217 codes
- Transaction stores both `originalAmount` and `convertedAmount` with separate currency codes
- Tag every model with a `jurisdiction: String` property for multi-country awareness

### Commit 3: Service Layer & Dependency Architecture
Create service protocols and `@Observable` view models forming the MVVM backbone.

**Services:**
- `FinanceDataService.swift` — Protocol for financial data access
- `ExchangeRateService.swift` — Protocol for FX rate fetching
- `ReceiptScannerService.swift` — Protocol for Vision OCR
- `LocationService.swift` — Protocol for location-based logic
- `NotificationService.swift` — Protocol for alerts/notifications
- `Implementations/` — Live and Mock implementations for every service

**Architecture rules:**
- Every `@Observable` class is marked `@MainActor`
- Services use async/await — no DispatchQueue anywhere
- Mock implementations exist for every service from Day 1
- Use Swift's native `Error` protocol with typed errors per domain

### Commit 4: Design System Foundation — Tokens & Theme

**DesignSystem structure:**
- `Tokens/` — ColorTokens, TypographyTokens, SpacingTokens, AnimationTokens
- `Theme/` — NomadFiTheme (environment-injected)
- `Components/` — CurrencyText, GlassCard, StatusBadge

**Design principles:**
- `.foregroundStyle()` exclusively
- All corner radii via `.clipShape(.rect(cornerRadius:))`
- Zero hard-coded font sizes — Dynamic Type only
- Semantic colors adapting to light/dark/high-contrast
- 4pt grid spacing system
- Liquid Glass translucency using Material and `visualEffect` modifiers

---

## Phase 1 — Onboarding & Jurisdiction Setup (Commits 5–8)

### Commit 5: Welcome & Value Proposition Screen
- Full-bleed illustration showing fragmented finances converging
- Headline: "Your money lives in three countries. Now it has one home."
- Single CTA: "Get Started"
- VoiceOver labels on every element; screen reads as coherent narrative
- Respect `accessibilityReduceMotion` and `accessibilityReduceTransparency`

### Commit 6: Jurisdiction Selection — "Where Does Your Money Live?"
- Stylized world map or flag-based selector
- Pre-populate common international student corridors (TT->CA->US, IN->US, NG->UK->US, etc.)
- Haptic feedback (`.selection`) on each selection
- Minimum 2 jurisdictions required with inline validation
- Store selections in SwiftData as `JurisdictionProfile` records
- Full VoiceOver support: each flag announces country name and currency

### Commit 7: Currency Configuration & Preferences
- Native `Picker` for currency selection
- Allow reordering with `.draggable` and `.dropDestination`
- Persist to SwiftData

### Commit 8: Account Connection Strategy Screen
- FinanceKit entitlement available: Apple Wallet connection flow with native privacy sheet
- Non-Apple accounts: manual account entry (name, type, currency, optional balance)
- Emphasize on-device privacy: "Your data never leaves your iPhone"
- Respect Apple's consent patterns — no dark patterns

---

## Phase 2 — The Universal Ledger / Dashboard (Commits 9–15)

### Commit 9: Dashboard Layout Shell
- Bottom `TabView` using modern `Tab` API with 4 tabs: Dashboard, Ledger, Tax Vault, Settings
- `NavigationStack` with `navigationDestination(for:)` patterns
- SF Symbols: `globe`, `list.bullet.rectangle`, `doc.text.viewfinder`, `gearshape`

### Commit 10: Global Net Worth Card
- Total net worth in home currency (Dynamic Type `.largeTitle`)
- Three smaller values in each jurisdiction's currency
- Animate with `contentTransition(.numericText())`
- `.number.precision(.fractionLength(2))` for all currency formatting
- `Material.ultraThinMaterial` for Liquid Glass aesthetic
- Pull-to-refresh to update exchange rates
- Full VoiceOver narration of all amounts

### Commit 11: Account Cards — Jurisdiction-Grouped
- Grouped by jurisdiction with flag + country name headers
- Each card: account name, institution, balance, currency
- `GlassCard` component from design system
- `LazyVStack` with pinned section headers
- Empty state with illustration + CTA

### Commit 12: Exchange Rate Ticker
- Horizontal scroller with relevant FX pairs (TTD/USD, CAD/USD, TTD/CAD)
- Fetch from free FX API, store in SwiftData `ExchangeRate` records
- Trend arrow + percentage change
- Tap for 7-day mini chart (Swift Charts)
- Cache locally with "Last updated" timestamp

### Commit 13: Smart Insights Section — "Your Money This Week"
- **FX Waste Alert:** "You spent $47 CAD using your US account. That cost $3.20 in hidden fees."
- **Arbitrage Opportunity:** "The USD is strong against TTD. Consider sending money home today."
- **Budget Warning:** "You've spent 80% of your San Francisco weekly budget."
- **Subscription Flag:** "Your Netflix CAD subscription is cheaper than US pricing. Keep it."
- Dedicated `InsightEngine` service with unit tests

### Commit 14: Dashboard Widget — WidgetKit Integration
- `NomadFiWidgetBundle`:
  - Small: Global net worth + trend
  - Medium: Net worth + top 2 accounts
  - Lock Screen: Net worth number (circular/inline)
- `AppIntentTimelineProvider` for modern widget architecture
- Update every 15 minutes or on significant change
- Liquid Glass widget style for iOS 26

### Commit 15: Dashboard Polish — Animations & Haptics
- Counting-up animation on net worth
- Stagger-animate account cards with `animation(.spring, value:)` + delay
- Custom Core Haptics pattern for pull-to-refresh
- Skeleton loading with `redacted(reason: .placeholder)`
- Respect `accessibilityReduceMotion`

---

## Phase 3 — The Ledger & Transaction Intelligence (Commits 16–21)

### Commit 16: Transaction List View
- Chronological, searchable list grouped by date with sticky section headers
- Each row: merchant, amount (original + home currency), category icon, jurisdiction flag
- `.searchable(text:)` with `localizedStandardContains()` filtering
- Filter chips by jurisdiction, category, date range
- `LazyVStack` for performance

### Commit 17: Transaction Detail View
- Original amount + currency, converted amount in home currency
- FX rate used vs. mid-market rate with delta display
- Category (auto-detected or user-assigned)
- Location (if available from FinanceKit)
- Tax relevance toggle -> tags for Tax Vault

### Commit 18: FinanceKit Integration Layer
- Request authorization via `FinanceStore.shared.requestAuthorization()`
- Handle all authorization states
- Fetch accounts and transactions with date predicates
- Map `FinanceKit.Transaction` to SwiftData `Transaction` model
- Real-time streaming via `FinanceStore.shared.transactionUpdates()`
- Graceful degradation without FinanceKit — manual entry works seamlessly
- Background delivery using iOS 26 FinanceKit APIs

### Commit 19: Manual Transaction Entry
- SwiftUI `Form` with sections: amount + currency picker, date, category, optional receipt photo
- Siri shortcut integration (implemented in Phase 5)
- Validate before save; haptic feedback on success

### Commit 20: "Real Cost" Calculator
- `realCost = amount x actualRate` vs `fairCost = amount x midMarketRate`
- Display delta: "This purchase cost you TTD 3.20 more than it should have"
- Aggregate deltas weekly/monthly for Insights
- Color indicator: green (fair), yellow (slight markup), red (significant markup)

### Commit 21: "Active Card" Recommendation Engine
- `CLLocationManager` to detect current country
- Cross-reference with accounts for lowest-fee option
- Persistent recommendation display
- Lock Screen Live Activity via ActivityKit when entering a new country
- Surface in dashboard Insights

---

## Phase 4 — The Tax Vault (Commits 22–27)

### Commit 22: Tax Vault Landing Screen
- Documents grouped by tax year and jurisdiction (US Source, Canadian Source, Trinidad Source)
- Thumbnail, merchant, amount, date, category per document
- Running totals per category
- Export -> zip file organized by jurisdiction

### Commit 23: Receipt Scanner — Vision Framework OCR
- Camera via `DataScannerViewController` (VisionKit) for live scanning
- Photo library import support
- `VNRecognizeTextRequest` with `.accurate` recognition level
- Extract: merchant name, total, date, line items
- Auto-detect currency from symbols or locale
- User confirmation before saving
- Store original image + metadata in SwiftData `TaxDocument`

### Commit 24: Auto-Categorization & Jurisdiction Tagging
- Rule-based categorization (keywords: "tuition" -> Education, "pharmacy" -> Medical)
- Auto-tag jurisdiction based on merchant location or currency
- User override with on-device learning from corrections

### Commit 25: Tax Category Management
- Pre-built NRA categories: Treaty Benefits, Education Expenses, Scholarship Income, Wages (J-1/F-1), Capital Gains
- Custom user categories with name, SF Symbol icon, applicable jurisdictions, deductible flag
- Stored in SwiftData, synced via iCloud

### Commit 26: Export & Report Generation
- Structured PDF per jurisdiction per tax year
- Contents: categorized totals, transaction list, receipt thumbnails
- Export as `.zip` with PDF + organized receipt images
- Share via `ShareLink`
- Filename: `NomadFi_TaxReport_US_2025.pdf`

### Commit 27: Tax Vault Onboarding & Education
- First-time NRA tax explanation
- Contextual tips via `.popoverTip()` with TipKit
- Links to IRS Publication 519 and CRA resources
- Education component for Social Impact differentiation

---

## Phase 5 — Subscription Arbitrage & Siri Integration (Commits 28–32)

### Commit 28: Subscription Detection
- Pattern-match on merchant name + recurring amounts at regular intervals
- Display: name, amount, currency, frequency, renewal date
- Equivalent cost in all user currencies
- Flag duplicates across jurisdictions

### Commit 29: Subscription Comparison Engine
- Look up pricing in user's other jurisdictions
- Calculate savings: "Netflix CAD = $16.99 CAD ~ $12.01 USD. US price = $15.49 USD. Save $3.48/month."
- Green badge for savings; aggregate annual savings potential

### Commit 30: App Intents — Siri Shortcuts
**Intents:**
- `LogExpenseIntent` — "Hey Siri, I just spent $15 USD on lunch"
- `CheckNetWorthIntent` — "Hey Siri, what's my net worth?"
- `ActiveCardIntent` — "Hey Siri, which card should I use?"
- `CheckBudgetIntent` — "Hey Siri, how much is left in my budget?"

Each conforms to `AppIntent` with `localizedStringResource`, `@Parameter`, and `.result(dialog:)`.

### Commit 31: Spotlight & App Shortcuts Integration
- `CSSearchableItem` entries for accounts and subscriptions
- `AppShortcutsProvider` for Lock Screen suggested shortcuts
- `.searchable` for in-app Spotlight indexing

### Commit 32: Notifications & Alerts System
- FX rate significant movement (>2% daily change)
- Subscription renewal reminders (3 days before)
- Weekly spending summary (Saturday morning)
- Budget threshold warnings (80%, 90%, 100%)
- `UNUserNotificationCenter` with proper authorization
- Respect Do Not Disturb

---

## Phase 6 — Accessibility & Inclusivity Excellence (Commits 33–37)

### Commit 33: VoiceOver Audit & Enhancement
- Every screen narrates as a coherent story
- Custom `accessibilityLabel` and `accessibilityHint` on every interactive element
- `accessibilityElement(children: .combine)` for related elements
- Custom swipe actions on complex cards
- Full eyes-free usability testing

### Commit 34: Dynamic Type at Every Scale
- Test at largest accessibility size (AX5)
- No text truncation — use `ScrollView` for large text
- Layouts reflow with `ViewThatFits`
- `.minimumScaleFactor()` only as last resort

### Commit 35: Color Accessibility
- WCAG 2.1 AA contrast ratios (4.5:1 for text)
- "Differentiate Without Color" support
- Increase Contrast mode tested
- Color-blind safe palette with pattern fills in Swift Charts

### Commit 36: Reduce Motion & Reduce Transparency
- `accessibilityReduceMotion` branch for every animation
- `accessibilityReduceTransparency` fallback for glass/blur effects
- Loading states work without animation

### Commit 37: Internationalization & Localization
- All strings in `Localizable.xcstrings`
- RTL layout support
- Locale-aware currency and date formatting
- Start with English; structure supports Spanish, French, Hindi, Mandarin

---

## Phase 7 — Polish, Performance & Award Readiness (Commits 38–44)

### Commit 38: Liquid Glass Design Polish
- Audit every screen against iOS 26 Liquid Glass design language
- Translucent bars, glass material effects, rounded surfaces
- Clear-look app icon style
- Light and dark mode testing

### Commit 39: Performance Optimization
- Profile with Instruments: Time Profiler, Allocations, Core Animation
- 60fps scrolling in transaction lists
- SwiftData queries use proper predicates (no fetch-all-then-filter)
- Receipt thumbnails properly downsampled
- Memory under 100MB for typical usage

### Commit 40: Error Handling & Edge Cases
- Network failure: cached data with "Last updated" banner
- FinanceKit denied: graceful fallback to manual mode
- Empty states for every list/section
- Invalid receipt scan: clear feedback + retry
- Currency conversion failure: show original currency with explanation

### Commit 41: Onboarding Refinement & First-Run Experience
- Full onboarding under 90 seconds
- "Why this matters" on every screen
- Skip option (not prominent) for returning users
- Sample/demo data on first dashboard load
- TipKit for progressive feature discovery

### Commit 42: Privacy & Security Hardening
- Minimal permissions requested
- Accurate App Privacy Nutrition Label
- No data leaves device unless user exports
- Keychain for sensitive tokens
- Biometric lock option (Face ID/Touch ID)
- Data governance explanation in Settings

### Commit 43: App Store Metadata & Screenshots
- Description emphasizing Social Impact
- 6.7" and 6.1" screenshots telling Problem -> Solution -> Impact story
- App Preview video: receipt scan -> insight flow
- Keywords: international student finance, cross-border money, FX tracker, NRA tax, global net worth

### Commit 44: Final Integration Test & Submission
- End-to-end test: onboarding -> add accounts -> scan receipt -> view insight -> export tax report -> Siri shortcut
- Accessibility audit with Accessibility Inspector
- Memory leak check with Instruments
- App Review Guidelines compliance (Section 5 — Finance)
- TestFlight beta to 5–10 international student testers
- Submit with supplementary notes on Social Impact

---

## Commit Map Summary

| Phase | Commits | Focus | ADA Category |
|-------|---------|-------|--------------|
| 0 | 1–4 | Scaffold, models, services, design system | Foundation |
| 1 | 5–8 | Onboarding & jurisdiction setup | Interaction, Delight |
| 2 | 9–15 | Dashboard & global net worth | Innovation, Visuals |
| 3 | 16–21 | Ledger, transactions, FinanceKit | Innovation |
| 4 | 22–27 | Tax Vault & receipt scanning | Social Impact |
| 5 | 28–32 | Subscriptions, Siri, Shortcuts | Innovation, Interaction |
| 6 | 33–37 | Accessibility deep pass | Inclusivity |
| 7 | 38–44 | Polish, performance, submission | All categories |

---

## Critical Technical Constraints

1. **FinanceKit** requires an entitlement and only works with Apple Card/Cash in the US and selected UK banks. Design the entire app to work beautifully without FinanceKit — manual entry is the primary flow for most international students.
2. **No third-party frameworks** unless explicitly approved. The entire app uses: SwiftUI, SwiftData, FinanceKit, VisionKit, Vision, Core Haptics, ActivityKit, WidgetKit, App Intents, Swift Charts, and TipKit.
3. **iOS 26 Liquid Glass** is the new design language. Translucent surfaces, content-focused UI, glass material effects. Study the WWDC25 session "Get to know the new design system" before designing any screen.
4. **Strict concurrency is non-negotiable.** Every `@Observable` class is `@MainActor`. All async work uses structured concurrency. No `DispatchQueue` anywhere.
5. **Dynamic Type at every size** is the difference between an award winner and a rejection. Test at AX5 before considering any screen "done."
