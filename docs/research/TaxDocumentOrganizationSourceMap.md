# Tax Document Organization Prompts — Phase 7E Source Map

This document records the official sources NomadFi cites in its
Phase 7E document-organization prompts, the rationale for what
the prompts deliberately do not claim, and where they intentionally
stay generic. It is an operational reference for anyone editing
the prompt service, not marketing copy.

The rule is narrow: any jurisdiction-specific recordkeeping
prompt must cite a tax-authority page from that jurisdiction.
Accountants' marketing pages, blogs, Reddit, and SEO finance
content are out of scope. If a tax authority does not publish a
clean retention duration, the prompt stays procedural and links
the regulator's page rather than restating a number it never
endorsed.

---

## 1. Scope of Phase 7E

Phase 7E ships **calm, deterministic prompts** rendered in Tax
Vault Learn that bridge the user from "I read the lesson" to "I
organized the right records." It does **not**:

- file taxes,
- claim a specific deduction is available,
- assert that the user has every required slip,
- send notifications, set reminders, or build a due-date engine,
- persist any new records.

Each region's prompts are derived on demand by
`TaxDocumentOrganizationPromptService` from the user's active
jurisdictions and the existing `TaxDocument` archive.

---

## 2. Prompt families

### State-dependent action prompts

These are not source-backed — they describe NomadFi's own
surfaces. They never make a tax claim.

| Kind | Trigger | Action |
| --- | --- | --- |
| `scanFirstDocument` | The Tax Vault archive holds **no** documents tagged with the region's country code. | "Open Review" — switches Tax Vault's peer-surface picker to Review so the user can scan or upload. |
| `verifyArchive` | The archive holds **at least one** document for the region. | "Open Archive" — switches the surface so the user can verify the year / jurisdiction grouping. |

### Recordkeeping principles prompts

One per surfaced region. Each carries at least one regulator
citation. Copy stays procedural — never asserts the user has
"everything" or that retention rules are uniform.

---

## 3. Per-region citations

### United States

NomadFi cites IRS pages only for U.S. recordkeeping. The IRS
deliberately does not publish a single uniform retention duration
— retention windows tie to the period of limitations for the
underlying record type. The prompt copy reflects that.

| Prompt | Primary sources |
| --- | --- |
| U.S. recordkeeping principles | IRS — [How long should I keep records?](https://www.eitc.irs.gov/businesses/small-businesses-self-employed/how-long-should-i-keep-records), [What kind of records should I keep](https://www.irs.gov/businesses/small-businesses-self-employed/what-kind-of-records-should-i-keep) |

### Canada

NomadFi cites CRA only for Canadian recordkeeping. CRA is the
only one of the three jurisdictions that publishes a clean,
single retention number on the page itself ("at least six years
from the end of the tax year"). The prompt restates this only
because the regulator's page does, and links the page directly so
the reader can confirm.

| Prompt | Primary source |
| --- | --- |
| Canada recordkeeping principles | CRA — [How long should you keep your income tax records?](https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/long-should-you-keep-your-income-tax-records.html) |

### Trinidad and Tobago

NomadFi cites IRD's small-business landing page only. IRD does
not publish a retention duration in the same place CRA does, so
the prompt stays generic — it surfaces the expectation to keep
records and links the IRD page. NomadFi explicitly does **not**
infer or restate a retention number for this jurisdiction.

| Prompt | Primary source |
| --- | --- |
| Trinidad and Tobago recordkeeping principles | IRD Trinidad and Tobago — [Small Business Person](https://www.ird.gov.tt/small-business-person) |

---

## 4. What the prompts deliberately do not claim

- **No fake completeness.** The action prompts are about
  NomadFi's own surfaces (the archive is empty / the archive has
  records). They never imply that the user has "everything they
  need" for filing.
- **No retention numbers without a regulator backing them.** Only
  CRA's six-year line is restated, and only because that exact
  number appears on CRA's page. The U.S. and TT prompts stay
  procedural by design.
- **No suitability framing.** The prompts do not tell the user
  whether to file, deduct, or claim anything. They route between
  Tax Vault's peer surfaces (Review / Archive) and surface
  regulator URLs.
- **No notifications, reminders, or due-date engine.** Phase 7E
  is a derived view over existing records, not a task system.
- **No new persistence.** No new `@Model`, no new SwiftData
  schema entry, no new background job. The Tax Vault `@Query`
  results feed the service on each render.

---

## 5. Editing rules

These rules govern future edits to
`TaxDocumentOrganizationPromptService.swift`. The focused tests
pin the corresponding behaviour.

1. **Primary sources only.** IRS / CRA / IRD or another tax
   authority. No accountants' marketing pages, blogs, or SEO
   tax content.
2. **Region honesty.** Region display names are absolute. Regions
   the catalogue does not cover are silently omitted from the
   prompt list — never replaced with a U.S. fallback.
3. **No retention-number invention.** If a tax authority does not
   publish a single retention duration, the prompt stays generic.
4. **Procedural language only.** "What this is / why a moment
   here helps." Never "you should file", "this is deductible",
   "you qualify", "compliant", or "you have everything you need."
5. **Action prompts are about NomadFi's surfaces, not tax
   outcomes.** The state-dependent prompts may use terms like
   "Review" and "Archive" because those are NomadFi's peer
   surfaces, not tax-authority labels.

---

## 6. Refresh discipline

Tax-authority pages move. The team should re-walk every URL in
this document at the start of each calendar quarter and confirm:

- the URL still resolves,
- the page still describes the same recordkeeping principle,
- the cited duration (CRA only) still matches what the regulator
  publishes,
- no superseding regulator page has replaced it.

If a URL has moved, update both
`TaxDocumentOrganizationPromptService.swift` and this document in
the same change.
