# NomadFi App Store Connect Submission Package

Version 1.0 (build 1) · Bundle ID `com.arieljtyson.NomadFi` · iPhone only

Everything needed to fill in App Store Connect for the first release. Every
length-limited field below has been measured against Apple's limit. The
listing images are in [`Screenshots/`](Screenshots).

---

## Before you submit

These are review risks found while preparing this package. None of them
blocks filling in the listing, but each should be resolved before you press
**Submit for Review**.

- [x] **No developer-only copy in release builds** (Guideline 2.2). The
  Plaid sandbox provider and its controls exist only in Debug builds, the
  Financial Connections footers are plain, and
  `NSLocalNetworkUsageDescription` no longer mentions validation phases.
- [x] **Exchange-rate attribution.** *Tools → Exchange Rates* credits "Rates
  by Exchange Rate API" with a link, as the free `open.er-api.com` terms
  require.
- [x] **Support contact.** The Support URL has a Support section with a
  tappable email: arieltyson30190@gmail.com.
- [x] **Frame the app as informational in review.** Guideline 5.1.1(ix)
  requires apps that provide regulated financial services to be submitted by
  the institution itself. NomadFi provides no banking, payments, lending or
  advice; it organises the person's own information. The Notes to Reviewer
  below say this explicitly. Keep that framing in the description.
- [ ] **Check the name is free.** If "NomadFi" is taken in App Store Connect,
  use **NomadFi – Cross-Border Money** (28 characters).
- [ ] **Answer the Accessibility questions** (§ 4b) only for what you have
  verified on a device.

Already done in the project for this release:

- iPad removed as a platform (`TARGETED_DEVICE_FAMILY = 1` on every target),
  so no iPad screenshots are needed.
- `ITSAppUsesNonExemptEncryption = NO` added to `NomadFi-Info.plist`, so App
  Store Connect will not ask about export compliance on each upload.
- `NSFaceIDUsageDescription` declared (App Lock now uses Face ID).

---

## 1. Core Metadata

| Field | Value | Length |
|---|---|---|
| **App Name** | NomadFi | 7 / 30 |
| **Subtitle** | Cross-border money, made clear | 30 / 30 |
| **Primary Category** | Finance | — |
| **Secondary Category** | Education | — |
| **Promotional Text** | see below | 151 / 170 |
| **Keywords** | see below | 99 / 100 |

**Promotional Text** (can be changed at any time without a new build):

```
One net worth across every country you live in, the right card before you buy, and receipts ready for tax season — all on your iPhone, with no account.
```

**Keywords** (no spaces after commas; words already in the name and subtitle
are left out because Apple indexes those separately):

```
international,student,currency,exchange,rate,fx,fees,credit,card,abroad,expat,net,worth,tax,receipt
```

---

## 2. App Description & URLs

**Description:**

```
NomadFi brings money that lives in more than one country into one clear picture. See your net worth across every country you call home, choose the right card before you pay, and keep receipts organised for tax season — without handing your financial life to anyone.

Every country you live in gets its own card, with its total in its own currency. Tap a card to see the accounts behind it and every transaction, newest first. Above them, your global net worth adds it all up in your home currency. Every amount shows its symbol and its currency code, so you always know which money you are looking at.

When you are about to spend, the Decisions tab helps you think it through. A purchase check compares your cards for foreign-transaction fees and rewards. A credit-timing check looks at statement dates and how much of your limit you are using before a large purchase. Describe a decision in your own words and, on devices with Apple Intelligence, NomadFi structures it for you on device. Recommendations come from clear, published rules and cited sources — never a guess.

Your data stays on your iPhone. There is no account to create, no sign-in, no analytics and no ads. Apple Intelligence features run on device. Lock NomadFi with Face ID, and delete everything in one step from Settings.

KEY FEATURES:
• Global net worth across countries and currencies
• One card per country, with its accounts and transactions
• Purchase card check for foreign-transaction fees and rewards
• Credit-timing check before large purchases
• On-device decision capture with Apple Intelligence, plus Siri and Shortcuts
• Exchange rates between every currency you use
• Subscription tracking with cross-border price comparison
• Ledger with CSV statement import, previewed before anything is saved
• Tax Vault: scan receipts on device and review likely tax-relevant transactions
• Short, source-backed lessons on tax and investing in your countries
• Home Screen and Lock Screen widgets, and Control Center controls
• Face ID App Lock

NomadFi organises your own information and links to official sources. It is not a bank, does not move money, and does not provide financial, tax or investment advice.

NomadFi is free, with no ads, no subscriptions and no in-app purchases.
```

Length: 2,260 / 4,000.

| Field | Value |
|---|---|
| **Support URL** | https://arieltyson.github.io/nomadfi-privacy/ (Support section, arieltyson30190@gmail.com) |
| **Marketing URL** | https://arieltyson.github.io/nomadfi-privacy/ |
| **Privacy Policy URL** | https://arieltyson.github.io/nomadfi-privacy/privacy/ |
| **Copyright** | © 2026 Ariel Tyson |
| **SKU** (suggested) | NOMADFI-IOS-001 |
| **Version** | 1.0 |
| **Price** | Free (all territories) |

---

## 3. App Review & Compliance Information

**Sign-In Required:** No. NomadFi has no accounts and no server.

**Notes to Reviewer:**

```
NomadFi is a personal organiser for people whose money spans more than one country. It is informational: it does not hold funds, move money, connect to banks in this version, or provide financial, tax or investment advice. All data is entered by the user and stored only on the device.

No sign-in is required. To review:

1. Onboarding: tap Get Started, choose two or more countries (for example Canada and United States), pick a home currency, and add an account with a balance on the Accounts step. Location access is optional and only suggests your current country.
2. Dashboard: global net worth, then one card per country. Tap a card to see its accounts and transactions.
3. Decisions: tap Purchase card check or Credit timing check and follow the form. "Capture decision" uses on-device Apple Intelligence where available and falls back to a typed form elsewhere.
4. Tools: Exchange Rates, Subscriptions, Ledger (with CSV import), Tax Vault (receipt scan from a photo, read on device) and Investing Learn.
5. Settings → Privacy & Security: turn on "Require Face ID" to see App Lock. "Delete All My Data" erases everything on the device.

Network use is limited to fetching public exchange rates (currency codes only). Apple FinanceKit support is present in code but inactive: the entitlement has not been granted, so the app reports it as unavailable.
```

**Age Rating:** answer **None / No** to every content question (violence,
sexual content, profanity, drugs, horror, gambling, contests, medical or
treatment information, user-generated content, messaging, unrestricted web
access). Links open specific official sources, not a general browser.
**Calculated rating: 4+.**

**Content Rights:** Yes, the app shows third-party content: public exchange
rates from open.er-api.com, used under its free terms with the required
attribution in *Tools → Exchange Rates*, and links to government and issuer pages. No
copyrighted media is bundled.

**Encryption:** `ITSAppUsesNonExemptEncryption = NO`. NomadFi uses only
Apple's operating-system encryption (HTTPS, Keychain, data protection) and
no custom cryptography. The key is already in `NomadFi-Info.plist`.

---

## 4. App Privacy Nutrition Labels

**Data Collected: No → "Data Not Collected".**

| Data the app touches | Leaves the device? | Why it is not "collected" |
|---|---|---|
| Accounts, balances, transactions, receipts, decisions | No | SwiftData on device; no server, no sync |
| Location | No | Turned into a country on device to suggest a card |
| Decision text | No | Structured by on-device Apple Intelligence |
| Face ID | No | Handled by the system; the app only gets pass or fail |
| Currency codes | Yes, to open.er-api.com | Public request for public rates; nothing tied to a person, not stored by the app |

No analytics, crash-reporting, advertising or tracking SDKs are linked, and
the app does not track (no `NSUserTrackingUsageDescription`).

> Re-check this label before any release that turns on Plaid or FinanceKit
> for end users, or adds crash reporting. Both would change the answer.

### 4b. Accessibility Nutrition Labels

App Store Connect asks which features work for the app's **common tasks**
(onboarding, viewing net worth and a country, running a check, adding a
transaction, scanning a receipt). Claim only what you have verified on a
device. Expected answers once verified:

| Feature | Expected | Verify by |
|---|---|---|
| Dark Interface | Yes | Every screen uses adaptive system colours |
| Larger Text | Yes | Walk the common tasks at the largest accessibility size |
| Differentiate Without Color | Yes | Status chips pair colour with a symbol |
| Reduced Motion | Yes | Animations are removed or dissolved |
| Sufficient Contrast | Verify | Contrast tests cover the brand pairs only |
| VoiceOver | Verify | One full pass of each common task |
| Voice Control | Verify | Same pass, with Voice Control |
| Captions / Audio Descriptions | Not applicable | The app has no video or audio |

---

## 5. Header, Search Results and Screenshots

### 5a. Creative assets (Header and Search Results tab)

Built from Apple's official templates
([asset best practices](https://developer.apple.com/app-store/asset-best-practices/)),
with everything that must be seen inside each template's **Art Safe Area**.
The rest is atmosphere that devices crop and the App Store overlays.

| Slot | File | Size | Art safe area | Content |
|---|---|---|---|---|
| Header | [`Creative/header.png`](Creative/header.png) | 3840 × 1646 | x 1097–2743, y 493–1154 | The globe-and-compass mark and "Wealth without borders." on the brand field. No UI, as Apple advises for headers; the App Store adds the name and icon. |
| Search Results | [`Creative/search-results.png`](Creative/search-results.png) | 3840 × 2560 | x 836–3004, y 765–1795 | "Every country. One net worth." beside the real Dashboard country cards, at their captured resolution. |

Both follow the content rules: no prices, URLs, copyright symbols, awards
or other platforms, and 4+ throughout. Rebuild with
`python3 Creative/make_creative_assets.py` after a UI or icon change, and
check each device crop with **Preview** in App Store Connect before saving.

### 5b. Screenshots (App Previews and Screenshots tab)

Upload each folder to its matching display class:

| Display class | Folder | Size | Required |
|---|---|---|---|
| iPhone with Dynamic Island (medium display), 6.1–6.3" | [`Screenshots/iPhone-medium-1206x2622/`](Screenshots/iPhone-medium-1206x2622) | 1206 × 2622 | **Yes** |
| iPhone with Dynamic Island (large display), 6.7–6.9" | [`Screenshots/iPhone-large-1320x2868/`](Screenshots/iPhone-large-1320x2868) | 1320 × 2868 | No, but keeps the biggest phones sharp |

App Store Connect scales these down for every smaller iPhone class. iPhone
Duo, iPad and Apple Watch need nothing: NomadFi runs on iPhone only.

All are opaque RGB PNGs. To rebuild them after a UI change:

1. Capture the raw screens from the real app with sample data, on an
   iPhone 17 Pro Max simulator in light mode with the 9:41 status bar:

   ```bash
   xcrun simctl status_bar booted override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
   TEST_RUNNER_APP_STORE_SCREENSHOTS=1 xcodebuild test -project NomadFi/NomadFi.xcodeproj -scheme NomadFi \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
     -only-testing:NomadFiUITests/AppStoreScreenshotTests
   ```

   Export the attachments from the result bundle into `Screenshots/raw/`
   (named `01-dashboard.png` and so on).
2. Run `python3 Screenshots/make_screenshots.py` (needs Pillow).

**Global settings:**

| Setting | Value |
|---|---|
| Device | iPhone 17 Pro Max simulator, light mode, no frame (screen with display corners) |
| Typography | SF Pro Display |
| Title | Bold, 36pt / 40pt line height, `#FFFFFF` |
| Subtitle | Regular, 20pt / 24pt line height, `#33D4B5` |
| Alignment | Centre |
| Background | Vertical gradient `#00352D` → `#06110F` |
| Contrast | Title 13.6:1, subtitle 7.3:1 on `#00352D` (WCAG AA) |

**Sequence:**

| # | Screen | Title | Subtitle | Subtitle hex | BG top | BG bottom |
|---|---|---|---|---|---|---|
| 1 | Dashboard: net worth and country cards | Every country.\nOne net worth. | Every account, in every currency. | `#33D4B5` | `#00352D` | `#06110F` |
| 2 | Canada: accounts and transactions | Tap a country.\nSee it all. | Accounts and spending, by country. | `#33D4B5` | `#00352D` | `#06110F` |
| 3 | Decisions | Decide before\nyou spend. | Card and credit checks before you buy. | `#33D4B5` | `#00352D` | `#06110F` |
| 4 | Tools → Exchange Rates | Rates without\nthe guesswork. | Every pair between your currencies. | `#33D4B5` | `#00352D` | `#06110F` |
| 5 | Tools → Tax Vault | Receipts ready\nfor tax season. | Scanned on your iPhone. Nothing uploads. | `#33D4B5` | `#00352D` | `#06110F` |
| 6 | Tools | Every tool,\none tap away. | Rates, receipts, subscriptions and more. | `#33D4B5` | `#00352D` | `#06110F` |

---

## 6. App Preview Video Strategy (optional, free toolchain)

App previews are optional. If you make one, it must show only the app's own
interface, last 15–30 seconds, and match the screenshot size.

1. **Capture:** connect the iPhone to the Mac, open QuickTime Player →
   File → New Movie Recording, and choose the iPhone as the camera. Record:
   Dashboard → tap Canada → back → Decisions → Purchase card check →
   Tools → Exchange Rates.
2. **Edit:** import the `.mov` into iMovie, trim to under 30 seconds, and
   add short text overlays matching the screenshot titles.
3. **Export:** File → Share → App Preview. iMovie sets the frame rate and
   resolution App Store Connect expects.

---

## 7. Developer CLI Scripts

Only needed for images made outside `make_screenshots.py`, which already
writes the exact sizes without alpha.

Resize to the required medium display (1206 × 2622):

```bash
mkdir -p resized && for f in *.png; do sips -z 2622 1206 "$f" --out "resized/$f"; done
```

Remove an alpha channel:

```bash
for f in *.png; do
  python3 -c "
from PIL import Image
img = Image.open('$f').convert('RGBA')
bg = Image.new('RGBA', img.size, (0, 0, 0, 255))
bg.paste(img, mask=img)
bg.convert('RGB').save('$f')
"
done
```

---

### References

- Apple Developer. *App Store Connect Help: Screenshot specifications.*
  https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- Apple Developer. *App Store Review Guidelines.*
  https://developer.apple.com/app-store/review/guidelines/
- Apple Developer. *App privacy details on the App Store.*
  https://developer.apple.com/app-store/app-privacy-details/
- Apple Developer. *Accessibility Nutrition Labels.*
  https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
