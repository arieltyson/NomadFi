// TaxEducationCatalog.swift
// NomadFi
//
// Locally-authored education starter content for the regions
// NomadFi's mission already covers (US, CA, TT). Every lesson
// cites at least one official source listed in docs/README.md's
// "Tax and Residency" section. None of the content here is
// generated, fetched, or cached at runtime.
//
// Editing rules:
//   • Keep lessons procedural — "what it is / why it matters /
//     what to review next" — never "you should file", "you
//     qualify", or any outcome claim.
//   • Every lesson must carry at least one source. The validation
//     helper below enforces this so the focused tests can pin it.
//   • Banned vocabulary: see `TaxEducationCatalogTests`
//     `copyGuardOnCatalogVocabulary()` for the full list.

import Foundation

/// Static, deterministic education catalogue. Consumers call
/// `lessons(for:)` and `checklist(for:)`; the selector in
/// `TaxEducationSelector` filters by the user's active
/// jurisdictions.
enum TaxEducationCatalog {

    // MARK: - Public API

    /// Starter lessons for `region`, in a stable order. Never
    /// empty for supported regions; the test suite pins the
    /// minimum count (2).
    static func lessons(for region: TaxEducationRegion) -> [TaxEducationLesson] {
        switch region {
        case .unitedStates: unitedStatesLessons
        case .canada: canadaLessons
        case .trinidadAndTobago: trinidadAndTobagoLessons
        }
    }

    /// The region's starter checklist. Every supported region has
    /// exactly one checklist in this slice.
    static func checklist(for region: TaxEducationRegion) -> TaxEducationChecklist {
        switch region {
        case .unitedStates: unitedStatesChecklist
        case .canada: canadaChecklist
        case .trinidadAndTobago: trinidadAndTobagoChecklist
        }
    }

    /// Every region the catalogue supports.
    static var supportedRegions: [TaxEducationRegion] {
        TaxEducationRegion.allCases
    }

    // MARK: - Validation

    /// Returns `true` when a lesson is safe to surface — has at
    /// least one official-source citation and non-empty core
    /// fields. Exposed so callers and tests can both rely on the
    /// same rule.
    static func isValid(_ lesson: TaxEducationLesson) -> Bool {
        !lesson.title.isEmpty
            && !lesson.whatItIs.isEmpty
            && !lesson.whyItMatters.isEmpty
            && !lesson.whatToReviewNext.isEmpty
            && !lesson.sources.isEmpty
    }

    // MARK: - Shared source entries

    private static let irsPub519 = TaxEducationSource(
        id: "irs-pub-519",
        publisher: "IRS",
        title: "Publication 519 — U.S. Tax Guide for Aliens",
        url: URL(string: "https://www.irs.gov/publications/p519")!,
        summary: "Official IRS guide covering resident / nonresident status and the substantial-presence test."
    )

    private static let irsJ1Scholars = TaxEducationSource(
        id: "irs-foreign-students-scholars",
        publisher: "IRS",
        title: "Foreign Students, Scholars, Teachers, Researchers and Exchange Visitors",
        url: URL(string: "https://www.irs.gov/individuals/international-taxpayers/foreign-students-and-scholars")!,
        summary: "IRS landing page for J-1 / F-1 / M-1 / Q visa holders, with links to filing reminders."
    )

    private static let irs1040NR = TaxEducationSource(
        id: "irs-1040nr-instructions",
        publisher: "IRS",
        title: "About Form 1040-NR (Nonresident Alien Income Tax Return)",
        url: URL(string: "https://www.irs.gov/forms-pubs/about-form-1040-nr")!,
        summary: "Official IRS page for the nonresident individual return, including the current-year instructions."
    )

    private static let irs8843 = TaxEducationSource(
        id: "irs-form-8843-instructions",
        publisher: "IRS",
        title: "About Form 8843 (Statement for Exempt Individuals)",
        url: URL(string: "https://www.irs.gov/forms-pubs/about-form-8843")!,
        summary: "Statement used by some F / J / M / Q visa holders to explain days of presence."
    )

    private static let craResidency = TaxEducationSource(
        id: "cra-residency",
        publisher: "CRA",
        title: "Determining your residency status",
        url: URL(string: "https://www.canada.ca/en/revenue-agency/services/tax/international-non-residents/individuals-leaving-entering-canada-non-residents/determining-your-residency-status.html")!,
        summary: "CRA walks through factual residency based on ties to Canada."
    )

    private static let craForeignStudents = TaxEducationSource(
        id: "cra-foreign-students",
        publisher: "CRA",
        title: "Taxes for international students studying in Canada",
        url: URL(string: "https://www.canada.ca/en/revenue-agency/services/tax/international-non-residents/individuals-leaving-entering-canada-non-residents/foreign-students.html")!,
        summary: "CRA guidance page for international students, including T2202 and T4A slips."
    )

    private static let craTFSA = TaxEducationSource(
        id: "cra-tfsa",
        publisher: "CRA",
        title: "The Tax-Free Savings Account",
        url: URL(string: "https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/tax-free-savings-account.html")!,
        summary: "CRA reference page for TFSA contribution-room rules, withdrawal effects, and reporting."
    )

    private static let craRRSP = TaxEducationSource(
        id: "cra-rrsp",
        publisher: "CRA",
        title: "RRSPs and related plans",
        url: URL(string: "https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/rrsps-related-plans.html")!,
        summary: "CRA landing page for Registered Retirement Savings Plans and similar registered accounts."
    )

    private static let ttBIR = TaxEducationSource(
        id: "tt-bir",
        publisher: "Board of Inland Revenue, Trinidad and Tobago",
        title: "Inland Revenue Division",
        url: URL(string: "https://www.ird.gov.tt/")!,
        summary: "Official BIR site for personal-income-tax administration in Trinidad and Tobago."
    )

    private static let ttMinistryOfFinance = TaxEducationSource(
        id: "tt-ministry-of-finance",
        publisher: "Ministry of Finance, Trinidad and Tobago",
        title: "Ministry of Finance",
        url: URL(string: "https://www.finance.gov.tt/")!,
        summary: "Policy and fiscal-framework publisher for Trinidad and Tobago."
    )

    private static let ttFIUTT = TaxEducationSource(
        id: "tt-fiutt",
        publisher: "FIUTT",
        title: "Financial Intelligence Unit of Trinidad and Tobago",
        url: URL(string: "https://www.fiu.gov.tt/")!,
        summary: "FIUTT sets AML / CFT reporting expectations relevant to financial records."
    )

    // MARK: - United States

    private static let unitedStatesLessons: [TaxEducationLesson] = [
        TaxEducationLesson(
            id: "us-resident-vs-nonresident",
            region: .unitedStates,
            title: "Resident vs. nonresident for U.S. tax purposes",
            whatItIs: "The IRS distinguishes between resident aliens and nonresident aliens for tax. Each status uses different forms and different rules about which income is taxed.",
            whyItMatters: "Status shapes which forms a cross-border earner is expected to file and which income is in scope. NomadFi does not determine status on your behalf — that is a personal, evidence-based review.",
            whatToReviewNext: [
                "Review the substantial-presence test and exceptions in IRS Publication 519.",
                "List the days of presence you had in the U.S. across the relevant calendar years.",
                "Note any visa category that may count as an exempt individual in the same publication.",
            ],
            sources: [irsPub519],
            escalationNote: "Status edge cases are judgment-intensive. Consider a qualified professional when the substantial-presence test is close to a threshold."
        ),
        TaxEducationLesson(
            id: "us-j1-student-reminders",
            region: .unitedStates,
            title: "J-1, F-1, and student filing reminders",
            whatItIs: "The IRS publishes a dedicated hub for foreign students, scholars, and exchange visitors. Some filings are expected even when no tax is owed.",
            whyItMatters: "Missing a procedural filing can complicate later visa or residency paperwork. Reviewing the IRS hub helps you see what is routinely expected of your visa category.",
            whatToReviewNext: [
                "Open the IRS foreign-students-and-scholars page and skim the checklist it links.",
                "Check whether Form 8843 applies to your visa category and tax year.",
                "Collect any 1042-S, W-2, or 1099 slips issued for the tax year.",
            ],
            sources: [irsJ1Scholars, irs8843],
            escalationNote: "Treaty positions and visa-specific exclusions have strict conditions. A cross-border-tax professional can confirm whether a particular line applies to you."
        ),
        TaxEducationLesson(
            id: "us-1040nr-basics",
            region: .unitedStates,
            title: "Form 1040-NR basics",
            whatItIs: "Form 1040-NR is the U.S. individual return used by many nonresident filers. The IRS publishes the current-year instructions alongside the form.",
            whyItMatters: "Filing on the correct form matters because nonresident rules differ from resident rules in meaningful ways (deductions, credits, dependents).",
            whatToReviewNext: [
                "Open the IRS \"About Form 1040-NR\" page and locate the current-year instructions.",
                "Note the filing-status options available to nonresident filers.",
                "Review any treaty articles referenced in the instructions before claiming a position.",
            ],
            sources: [irs1040NR],
            escalationNote: "Complex mixed-status years, treaty claims, and late filings are areas where a qualified professional adds real value."
        ),
    ]

    private static let unitedStatesChecklist = TaxEducationChecklist(
        region: .unitedStates,
        title: "U.S. tax-season preparation",
        items: [
            TaxEducationChecklistItem(id: "us-review-status", text: "Review residency status against IRS Publication 519."),
            TaxEducationChecklistItem(id: "us-collect-slips", text: "Collect W-2, 1042-S, 1099, and scholarship records for the tax year."),
            TaxEducationChecklistItem(id: "us-check-8843", text: "Check whether Form 8843 applies to your visa category."),
            TaxEducationChecklistItem(id: "us-review-treaty", text: "Review any treaty positions against the IRS treaty tables before claiming."),
            TaxEducationChecklistItem(id: "us-keep-records", text: "Keep supporting records for the period the IRS suggests in the current-year instructions."),
        ],
        escalationNote: "Education only. Not a substitute for a qualified professional. NomadFi does not file on your behalf."
    )

    // MARK: - Canada

    private static let canadaLessons: [TaxEducationLesson] = [
        TaxEducationLesson(
            id: "ca-residency-basics",
            region: .canada,
            title: "Canadian tax residency basics",
            whatItIs: "CRA determines tax residency from factual ties to Canada — dwelling, spouse, dependents, and length of stay. Residency is not the same as immigration status.",
            whyItMatters: "Residency status drives which income CRA considers in scope and which slips you are expected to include.",
            whatToReviewNext: [
                "Read CRA's residency-determination page carefully.",
                "Sketch your ties to Canada and any secondary ties for the tax year.",
                "Check whether a tax treaty with another jurisdiction affects the result.",
            ],
            sources: [craResidency],
            escalationNote: "Mixed-year arrivals and departures are judgment-intensive. When ties are close to a threshold, consider a CRA-registered professional."
        ),
        TaxEducationLesson(
            id: "ca-international-students",
            region: .canada,
            title: "International student considerations",
            whatItIs: "CRA maintains a student-focused hub covering slips like T2202 and T4A, residency interaction with study permits, and filing reminders.",
            whyItMatters: "Study-permit terms, length of stay, and family ties all interact with residency. Reviewing CRA's student page keeps the procedural basics in one place.",
            whatToReviewNext: [
                "Open CRA's international-students page and scan the links it surfaces.",
                "Collect T2202 (tuition) and any T4A (scholarship / grant) slips.",
                "Note residency ties from the semester schedule and living arrangements.",
            ],
            sources: [craForeignStudents, craResidency],
            escalationNote: "CRA's own guidance is the right baseline. A CRA-registered professional can help when residency or slip treatment is unclear."
        ),
        TaxEducationLesson(
            id: "ca-tfsa-rrsp-highlevel",
            region: .canada,
            title: "TFSA and RRSP at a high level",
            whatItIs: "The Tax-Free Savings Account (TFSA) and Registered Retirement Savings Plan (RRSP) are registered accounts with specific contribution-room, withdrawal, and reporting rules set by CRA.",
            whyItMatters: "Contribution-room mistakes can carry penalties, and residency status affects TFSA eligibility. CRA's pages track the current-year numbers and rules.",
            whatToReviewNext: [
                "Look up your current TFSA and RRSP room in CRA My Account — NomadFi cannot read those numbers.",
                "Review TFSA rules about residency and non-resident contributions.",
                "Review RRSP rules about deduction limits and over-contribution relief.",
            ],
            sources: [craTFSA, craRRSP],
            escalationNote: "Registered-account rules change each year. A CRA-registered professional can confirm how a particular move interacts with the current year's limits."
        ),
    ]

    private static let canadaChecklist = TaxEducationChecklist(
        region: .canada,
        title: "Canada tax-season preparation",
        items: [
            TaxEducationChecklistItem(id: "ca-review-residency", text: "Review residency status against CRA's determination page."),
            TaxEducationChecklistItem(id: "ca-collect-slips", text: "Collect T4, T2202, T4A, and any other relevant slips for the tax year."),
            TaxEducationChecklistItem(id: "ca-verify-room", text: "Verify TFSA and RRSP contribution room against CRA My Account before contributing."),
            TaxEducationChecklistItem(id: "ca-keep-records", text: "Keep supporting records for the period CRA's current-year guidance suggests."),
        ],
        escalationNote: "Education only. Not a substitute for a CRA-registered professional. NomadFi does not file on your behalf."
    )

    // MARK: - Trinidad and Tobago

    private static let trinidadAndTobagoLessons: [TaxEducationLesson] = [
        TaxEducationLesson(
            id: "tt-personal-tax-basics",
            region: .trinidadAndTobago,
            title: "Local tax basics in Trinidad and Tobago",
            whatItIs: "The Board of Inland Revenue (BIR), under the Ministry of Finance, administers personal income tax in Trinidad and Tobago. Residents typically have ongoing BIR obligations.",
            whyItMatters: "Knowing the publishing authorities — BIR and the Ministry of Finance — helps you find current-year thresholds and procedural updates from a single official source.",
            whatToReviewNext: [
                "Bookmark the BIR site and the Ministry of Finance site.",
                "Check whether a BIR number is required for your situation.",
                "Look up the current-year personal-income-tax thresholds on the BIR site.",
            ],
            sources: [ttBIR, ttMinistryOfFinance],
            escalationNote: "A T&T-registered accountant is the right escalation when BIR filings interact with foreign income or cross-border employment."
        ),
        TaxEducationLesson(
            id: "tt-compliance-records",
            region: .trinidadAndTobago,
            title: "Compliance records in Trinidad and Tobago",
            whatItIs: "BIR and the Financial Intelligence Unit (FIUTT) set record-keeping and reporting expectations for financial records held by residents and some non-residents.",
            whyItMatters: "Keeping orderly records makes it straightforward to respond to official information requests and to reconcile cross-border transactions later.",
            whatToReviewNext: [
                "Keep local pay slips and tax-deduction documents as BIR suggests.",
                "Review FIUTT publications for AML / CFT record-keeping expectations.",
                "Store cross-border transaction records alongside the local ones.",
            ],
            sources: [ttBIR, ttFIUTT],
            escalationNote: "A T&T-registered accountant can confirm record-retention periods specific to your situation."
        ),
    ]

    private static let trinidadAndTobagoChecklist = TaxEducationChecklist(
        region: .trinidadAndTobago,
        title: "Trinidad and Tobago record-keeping basics",
        items: [
            TaxEducationChecklistItem(id: "tt-bir-number", text: "Check whether a BIR number applies to your situation."),
            TaxEducationChecklistItem(id: "tt-collect-slips", text: "Collect local pay slips and tax-deduction documents."),
            TaxEducationChecklistItem(id: "tt-keep-records", text: "Store cross-border transaction records alongside the local ones."),
            TaxEducationChecklistItem(id: "tt-review-fiutt", text: "Skim FIUTT publications for current AML / CFT expectations."),
        ],
        escalationNote: "Education only. Not a substitute for a T&T-registered accountant. NomadFi does not file on your behalf."
    )
}
