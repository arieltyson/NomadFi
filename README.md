<div align="center">

# NomadFi 💷

### Wealth without borders

<kbd>
    <img src="" width="800" height="500">
</kbd>

## Project Description 🎨

"NomadFi" is an iOS app built with SwiftUI that acts as a **Personal CFO for international students** managing money across multiple countries. Instead of juggling separate banking apps across jurisdictions, NomadFi unifies fragmented finances into a single dashboard that surfaces hidden costs, optimizes payment decisions, and automates cross-border tax compliance.

The app applies [Ramp's](https://ramp.com) B2B spend-management logic to the personal B2C context — combining Apple's `FinanceKit` for on-device financial data, `VisionKit` for receipt OCR, `App Intents` for Siri automation, and `ActivityKit` for Live Activity card recommendations to eliminate the "financial leakage" (hidden FX fees, poor exchange rates, tax confusion) that costs international students real money every day.

Current personal finance apps are domestic-focused. They break when you add a Trinidadian bank account, a Canadian credit card, and a US J-1 salary. **NomadFi doesn't.**


## Highlights 💫
<div align="left">

### The Universal Ledger 🌍
- **Global Net Worth dashboard** aggregates accounts across jurisdictions (TTD, CAD, USD) using real-time mid-market exchange rates — so you always know exactly how rich you are in your home currency vs. your spending currency.
- **FinanceKit integration** pulls Apple Card/Cash data on-device with full privacy, while **manual entry** supports any international bank seamlessly.

### Arbitrage Intelligence 💡
- **"Active Card" engine** uses `CoreLocation` to detect your current country and recommends the optimal payment source — eliminating hidden FX fees before you tap.
- **"Real Cost" calculator** reveals the true home-currency cost of every transaction, exposing the gap between what you paid and the mid-market fair rate.

### The Tax Vault 🗄️
- **Receipt scanner** powered by `VisionKit` (`DataScannerViewController`) and the `Vision` framework extracts merchant names, amounts, and dates from receipts using on-device OCR.
- **Auto-categorization** tags documents by jurisdiction and tax category (Treaty Benefits, Education Expenses, J-1 Wages), then exports organized reports at tax season.

### Subscription Arbitrage 💰
- **Cross-border price comparison** detects recurring subscriptions and checks pricing across the user's jurisdictions — surfacing savings like "Keep your Canadian Netflix; it's 20% cheaper than switching to US pricing."

### Siri & System Integration 🗣️
- **App Intents** enable voice-first interactions: *"Hey Siri, I just spent $15 USD on lunch"* logs a transaction; *"Which card should I use?"* returns a location-aware recommendation.
- **WidgetKit** brings global net worth to the Home Screen; **ActivityKit** delivers real-time card recommendations on the Lock Screen.

### Production Hardening & Accessibility 🦾
- **Accessibility-first design** ensures full VoiceOver narratives, Dynamic Type at every scale (including AX5), and complete support for Reduce Motion, Reduce Transparency, and Differentiate Without Color.
- **Privacy-first architecture** keeps all financial data on-device — nothing leaves the iPhone unless the user explicitly exports.

</div>

## Screenshots

<div style="display: flex; justify-content: center; align-items: center;">
    <kbd>
        <img src="" alt="Dashboard" width="200">
    </kbd>
    <kbd>
        <img src="" alt="Ledger" width="200">
    </kbd>
    <kbd>
        <img src="" alt="Active Card" width="200">
    </kbd>
</div>

<div style="display: flex; justify-content: center; align-items: center;">
    <kbd>
        <img src="" alt="Tax Vault" width="200">
    </kbd>
    <kbd>
        <img src="" alt="Receipt Scanner" width="200">
    </kbd>
    <kbd>
        <img src="" alt="Subscriptions" width="200">
    </kbd>
</div>

## Technologies Used 💻

This project leverages modern Swift, SwiftUI, and Apple platform APIs for a native, privacy-first cross-border finance experience.

- [x] Swift 6.2
- [x] SwiftUI
- [x] Observation framework
- [x] Swift Concurrency (`async/await`, actors, strict concurrency)
- [x] Swift Testing + XCTest UI Testing
- [x] SwiftData
- [x] FinanceKit
- [x] VisionKit (`DataScannerViewController`)
- [x] Vision (Text Recognition)
- [x] Core Haptics
- [x] CoreLocation
- [x] ActivityKit + WidgetKit (Live Activities & Widgets)
- [x] AppIntents + Shortcuts (Siri Integration)
- [x] Charts
- [x] TipKit
- [x] UserNotifications
- [x] StoreKit
- [x] OSLog (Structured Logging)

## Skills Demonstrated 🥋

This project is designed to showcase distinguished-level iOS engineering practices:

- [x] **SYSTEM DESIGN**: Privacy-first, on-device architecture with graceful degradation across FinanceKit availability, network conditions, and jurisdiction coverage.
- [x] **CROSS-BORDER DATA MODELING**: SwiftData schema that natively represents multi-currency transactions, jurisdiction-aware accounts, and real-time FX rate snapshots.
- [x] **PLATFORM INTEGRATION**: Deep integration with FinanceKit, VisionKit, App Intents, ActivityKit, WidgetKit, and CoreLocation for a system-native experience.
- [x] **SOCIAL IMPACT**: Purpose-built tooling that addresses a real affordability crisis — making hidden FX fees visible and cross-border tax compliance manageable for a vulnerable population.
- [x] **ACCESSIBILITY EXCELLENCE**: VoiceOver narratives, Dynamic Type at AX5, Reduce Motion/Transparency support, and WCAG 2.1 AA contrast compliance on every screen.
- [x] **TESTABILITY**: Protocol-oriented service layer with mock implementations from Day 1, enabling comprehensive unit testing and SwiftUI Previews.

## Architecture 🏗️

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

## Contributing ⚙️

Contributions are welcome. If you have ideas for features, architecture improvements, or bug fixes, open an issue or submit a pull request. Please keep changes aligned with the project's privacy-first, accessibility-first, and on-device-first design principles.

## License 🪪

All rights reserved. See [LICENSE](LICENSE) for details.

</div>
