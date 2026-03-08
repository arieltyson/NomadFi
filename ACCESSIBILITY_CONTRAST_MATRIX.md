# NomadFi Contrast Verification Matrix

Use this checklist to complete Phase 1 contrast verification on a physical iPhone for the common tasks in `ACCESSIBILITY_AUDIT.md`.

## Test Setup

- Device: iPhone (latest iOS 26.x available)
- App appearance passes:
  - Light mode + standard contrast
  - Dark mode + standard contrast
  - Light mode + Increase Contrast
  - Dark mode + Increase Contrast
- Accessibility settings:
  - Settings -> Accessibility -> Display & Text Size -> Increase Contrast (toggle ON/OFF)

## Pass Criteria

- Text and icons on actionable controls are readable at a glance.
- Selected state remains clear in both standard and increased contrast.
- Foreground/background pairs meet WCAG AA intent for normal UI text (4.5:1 target).
- No element relies on color alone for essential selection state.

## Common Task Matrix

| # | Common Task | Light Standard | Dark Standard | Light + Increased | Dark + Increased | Notes / Evidence |
|---|-------------|----------------|---------------|-------------------|------------------|------------------|
| 1 | Onboarding welcome CTA (Get Started) | [ ] | [ ] | [ ] | [ ] | |
| 2 | Jurisdiction selection rows (selected/unselected) | [ ] | [ ] | [ ] | [ ] | |
| 3 | Home currency selection rows (selected/unselected) | [ ] | [ ] | [ ] | [ ] | |
| 4 | Account setup actions (Add Account, Finish Setup) | [ ] | [ ] | [ ] | [ ] | |
| 5 | Dashboard core cards and key icons | [ ] | [ ] | [ ] | [ ] | |
| 6 | Ledger filter chips (selected/unselected) | [ ] | [ ] | [ ] | [ ] | |
| 7 | Ledger Active Card banner | [ ] | [ ] | [ ] | [ ] | |
| 8 | Tax Vault empty state primary action | [ ] | [ ] | [ ] | [ ] | |
| 9 | Subscription confidence badges | [ ] | [ ] | [ ] | [ ] | |
| 10 | Savings opportunity badges/banner | [ ] | [ ] | [ ] | [ ] | |
| 11 | Settings jurisdiction “Home” badge | [ ] | [ ] | [ ] | [ ] | |
| 12 | Tab bar selected icons/labels | [ ] | [ ] | [ ] | [ ] | |

## Sign-Off

- Date:
- Device + OS:
- Tester:
- Result:
  - [ ] Phase 1 contrast verification passed
  - [ ] Follow-up fixes required
