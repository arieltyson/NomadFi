# NomadFi Accessibility Audit Plan

Accessibility Nutrition Labels evaluation plan for App Store Connect submission.

This document maps NomadFi to Apple's nine Accessibility Nutrition Label features, identifies what appears ready in code, what needs validation on-device, and what must be fixed before claiming support.

## Common Tasks Checklist

These are the core tasks users must be able to complete with each claimed accessibility feature.

| # | Common Task | Screens / Flows |
|---|-------------|-----------------|
| 1 | Complete onboarding welcome and proceed | Welcome -> Jurisdiction -> Currency -> Account setup |
| 2 | Select at least two jurisdictions | JurisdictionSelectionView |
| 3 | Select home currency | CurrencyConfigurationView |
| 4 | Add first account or finish setup without one | AccountConnectionView + AddAccountSheet |
| 5 | View global net worth and jurisdiction account cards | DashboardView |
| 6 | Refresh exchange rates and review insights | DashboardView |
| 7 | Search/filter ledger transactions | LedgerView + TransactionFilterChips |
| 8 | Add a manual transaction | AddTransactionView |
| 9 | Review transaction detail and Real Cost analysis | TransactionDetailView + RealCostCard |
| 10 | Scan and confirm a tax receipt | TaxVaultView + ReceiptConfirmationView |
| 11 | Browse tax docs and open document detail | TaxVaultView + TaxDocumentDetailView |
| 12 | Export annual tax report | TaxVaultView export action |
| 13 | Review detected subscriptions and confirm/dismiss | SubscriptionsView + DetectedSubscriptionCard |
| 14 | Add manual subscription | AddSubscriptionView |
| 15 | Configure security/notifications/privacy settings | SettingsView |
| 16 | Complete first-launch experience | SplashView + onboarding entry |

## Feature-by-Feature Evaluation

### 1) VoiceOver
Current State: Mostly ready

What's done:
- Broad use of `.accessibilityElement(children: .combine)` and custom labels on key cards/rows.
- Onboarding selection rows expose selected state and hints.
- Decorative icon suppression is in place in multiple views.
- Key headers use `.accessibilityAddTraits(.isHeader)` in dashboard/ledger/subscriptions.

Gaps to close:
- Add explicit accessibility hints for key confirmation actions where intent may be ambiguous (for example confirm/dismiss in subscription detection, export flows).
- Validate every common task end-to-end on device with VoiceOver enabled (focus order, rotor navigation, form controls in sheets).
- Add automated accessibility smoke coverage in UI tests (currently tests are template-only).

Verdict:
- Engineering readiness is high, but claim only after full on-device matrix pass.

### 2) Voice Control
Current State: Ready (code-level)

What's done:
- Interaction model uses standard SwiftUI controls (`Button`, `Toggle`, `Picker`, `TextField`, `NavigationLink`, `PhotosPicker`).
- No custom gesture recognizers or `onTapGesture` dependence on core flows.

Gaps to close:
- Add optional `.accessibilityInputLabels()` aliases for important controls (nice-to-have).
- Run device validation with Voice Control "Show Names" and complete all common tasks.

Verdict:
- Likely safe to claim after one manual validation pass.

### 3) Larger Text
Current State: Mostly ready

What's done:
- Typography is centralized in Dynamic Type-based tokens.
- Several components branch layout for accessibility sizes using `dynamicTypeSize.isAccessibilitySize`.

Gaps to close:
- Audit one-line truncation hotspots in core rows/cards:
  - `NomadFi/NomadFi/Features/TaxVault/ReceiptConfirmationView.swift`
  - `NomadFi/NomadFi/Features/TaxVault/Components/TaxDocumentRow.swift`
  - `NomadFi/NomadFi/Features/Ledger/Components/TransactionRowView.swift`
  - `NomadFi/NomadFi/Features/Subscriptions/Components/DetectedSubscriptionCard.swift`
  - `NomadFi/NomadFi/Features/Subscriptions/Components/SubscriptionRowView.swift`
- Recheck fixed-size decorative symbols (welcome/splash/lock) to ensure they do not crowd content at AX sizes.

Verdict:
- Close to claimable once truncation checks are addressed and tested at maximum accessibility text sizes.

### 4) Dark Interface
Current State: Mostly ready

What's done:
- App uses system surfaces/materials (`systemBackground`, secondary/tertiary surfaces, material fallbacks).
- Brand colors have light/dark asset variants.
- Root tint is centralized.

Gaps to close:
- Validate all common tasks in dark mode on device, especially form sheets and empty states.
- Confirm widget extension surfaces/text also remain readable in dark appearance.

Verdict:
- Likely claimable after dark-mode regression pass.

### 5) Differentiate Without Color Alone
Current State: Partially ready

What's done:
- Many status areas already include text and icons with color (for example confidence badges, FX analysis text).
- Reusable helpers exist for differentiate-without-color support.

Gaps to close:
- Active filter chips in ledger rely primarily on color for selected state:
  - `NomadFi/NomadFi/Features/Ledger/Components/TransactionFilterChips.swift`
- Differentiate-without-color helper is defined but not applied in critical flows.
- Add explicit non-color indicators for selected/active/disabled states where color is currently primary.

Verdict:
- Do not claim yet.

### 6) Sufficient Contrast
Current State: Not ready (primary blocker)

What we measured from current tokens:
- `BrandPrimary` light (`0.000, 0.420, 0.353`) vs white text: **6.45:1** (passes AA).
- `BrandPrimary` dark (`0.000, 0.788, 0.655`) vs white text: **2.12:1** (fails AA).
- `BrandSecondary` dark vs white text: **1.87:1** (fails AA).
- `BrandSecondary` light vs white text: **4.05:1** (below 4.5:1 for normal text).

Code risk points:
- Global tint applies brand color app-wide:
  - `NomadFi/NomadFi/App/NomadFiApp.swift`
- Prominent and bordered controls are widely used with tint-driven foreground behavior.
- Explicit white-on-brand usage in selected chips:
  - `NomadFi/NomadFi/Features/Ledger/Components/TransactionFilterChips.swift`
- No `accessibilityIncreaseContrast` handling exists in production UI.

Verdict:
- Do not claim yet.

### 7) Reduced Motion
Current State: Mostly ready

What's done:
- Shared reduce-motion animation modifier exists.
- Splash and onboarding hero symbol effect respect reduce motion.
- Dashboard list/value animations gate off motion where expected.

Gaps to close:
- Audit remaining unconditional `withAnimation` calls (for example app lifecycle blur transitions) and gate where appropriate.
- Validate each common flow with Reduce Motion enabled.

Verdict:
- Likely claimable after a short cleanup and manual pass.

### 8) Captions
Current State: Not applicable

Reasoning:
- App does not provide core video/audio media playback experiences requiring timed captions.

Verdict:
- Mark as not applicable unless media content is added.

### 9) Audio Descriptions
Current State: Not applicable

Reasoning:
- No video content requiring descriptive narration tracks.

Verdict:
- Mark as not applicable unless media content is added.

## Summary Matrix

| Feature | Status | Can Indicate Support Now? | Work Required |
|---------|--------|---------------------------|---------------|
| VoiceOver | Mostly ready | After validation | End-to-end VoiceOver task pass + minor hints |
| Voice Control | Ready (code-level) | After validation | Voice Control task pass, optional input labels |
| Larger Text | Mostly ready | After fixes | Truncation review and AX-size validation |
| Dark Interface | Mostly ready | After validation | Full dark-mode regression pass |
| Differentiate Without Color Alone | Partially ready | No | Add non-color state indicators in core flows |
| Sufficient Contrast | Not ready | No | Token/button/chip contrast overhaul + Increase Contrast support |
| Reduced Motion | Mostly ready | After fixes | Gate remaining animations + validate on device |
| Captions | N/A | N/A | None |
| Audio Descriptions | N/A | N/A | None |

## Priority Action Plan

### Phase 0 - Baseline and Matrix Setup (1 day)
- Build an iPhone matrix: common tasks (rows) x 9 accessibility features (columns).
- Define pass criteria per task and feature before changes.
- Add a shared checklist for manual QA evidence (screen recording + notes).

### Phase 1 - Contrast and Token Remediation (2-3 days) [Blocker]
- Split brand usage into semantic roles:
  - Accent color (icons, selected indicators).
  - Action fill color (filled buttons/chips).
  - On-action foreground color.
- For dark mode, either:
  - darken action fill so white text reaches >= 4.5:1, or
  - keep bright fill and force dark foreground text with >= 4.5:1.
- Replace explicit white-on-brand chip text with semantic foreground token.
- Add support for `accessibilityIncreaseContrast` with stronger variants.
- Re-run contrast checks on all common task screens.

### Phase 2 - Differentiate Without Color Alone (1-2 days)
- Update filter chips to include a checkmark or shape change when selected.
- Apply the existing differentiate-without-color helper to status indicators.
- Ensure selected/active states communicate via text/icon/shape, not hue alone.

### Phase 3 - VoiceOver and Larger Text Hardening (1-2 days)
- Remove or relax one-line truncation where it blocks comprehension.
- Add explicit hints for high-impact actions (save/export/confirm/dismiss).
- Validate onboarding and form sheets at largest text sizes.

### Phase 4 - Reduced Motion and Regression Tests (1 day)
- Gate remaining non-essential animations under Reduce Motion.
- Add UI tests for:
  - onboarding completion,
  - add transaction,
  - receipt confirmation,
  - add subscription,
  - settings flows,
  with accessibility-focused launch configurations.

### Phase 5 - App Store Connect Submission Prep (0.5-1 day)
- Fill Accessibility Nutrition Labels only for verified features.
- Add an accessibility URL describing:
  - supported features,
  - known limitations,
  - setup tips,
  - contact channel for accessibility feedback.

## Device Testing Recommendations

Test on physical iPhone with these settings enabled one at a time:
- VoiceOver
- Voice Control
- Larger Text at maximum accessibility size
- Dark Mode
- Differentiate Without Color
- Increase Contrast
- Reduce Motion
- Reduce Transparency

For each setting, complete every common task in this document before claiming support.

## Immediate Design Decision Recommendation

Given your feedback on contrast and the current green palette:
- Keep the green identity for accents and selected states.
- Introduce a separate "action fill" green specifically for filled buttons/chips to guarantee contrast in both light and dark.
- Stop depending on one global tint color for all interaction states.

This keeps the NomadFi brand while meeting accessibility expectations for App Store labels and HIG alignment.
