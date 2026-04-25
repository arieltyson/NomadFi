// InvestingEducationCatalog.swift
// NomadFi
//
// Locally-authored investing-education starter content. Every
// lesson cites at least one regulator / investor-protection /
// tax-authority source. Nothing here is fetched, cached, or
// generated at runtime; nothing is investment advice.
//
// Sources consulted (each lesson lists its specific anchor):
//   • Investor.gov / U.S. SEC for the universal concept lessons
//     (index funds, ETFs, asset allocation, fees, time horizon).
//   • IRS for U.S. retirement-account-type lessons (IRA basics).
//   • CIRO for Canadian fees + investor-rights lessons.
//   • CIPF for Canadian investor-protection coverage.
//   • CRA for TFSA + RRSP basics.
//
// Editing rules:
//   • Procedural language only — "what it is / why it matters /
//     what to review next". Never "you should buy", "best fund",
//     "this is right for you", "you'll earn", or any outcome /
//     suitability claim.
//   • Every lesson must carry at least one source. The validation
//     helper enforces this so the focused tests pin it.
//   • Banned vocabulary is enumerated in
//     `InvestingEducationCatalogTests.copyGuardOnCatalogVocabulary()`.

import Foundation

/// Static, deterministic investing-education catalogue.
enum InvestingEducationCatalog {

    // MARK: - Public API

    static func lessons(for region: InvestingEducationRegion) -> [InvestingEducationLesson] {
        switch region {
        case .unitedStates: unitedStatesLessons
        case .canada: canadaLessons
        }
    }

    static func checklist(for region: InvestingEducationRegion) -> InvestingEducationChecklist {
        switch region {
        case .unitedStates: unitedStatesChecklist
        case .canada: canadaChecklist
        }
    }

    static var supportedRegions: [InvestingEducationRegion] {
        InvestingEducationRegion.allCases
    }

    /// Returns `true` when a lesson is safe to surface — has at
    /// least one official-source citation and non-empty core
    /// fields. Exposed so callers and tests rely on the same rule.
    static func isValid(_ lesson: InvestingEducationLesson) -> Bool {
        !lesson.title.isEmpty
            && !lesson.whatItIs.isEmpty
            && !lesson.whyItMatters.isEmpty
            && !lesson.whatToReviewNext.isEmpty
            && !lesson.sources.isEmpty
    }

    // MARK: - Shared source entries

    // ---- Investor.gov / SEC -----------------------------------------

    private static let investorGovIndexFunds = InvestingEducationSource(
        id: "investorgov-mutual-funds-and-etfs",
        publisher: "Investor.gov / U.S. SEC",
        title: "Mutual Funds and ETFs",
        url: URL(string: "https://www.investor.gov/introduction-investing/investing-basics/investment-products/mutual-funds-and-exchange-traded-4")!,
        summary: "SEC's Office of Investor Education and Advocacy explains how mutual funds and ETFs work, including index-fund construction."
    )

    private static let investorGovETFs = InvestingEducationSource(
        id: "investorgov-etfs",
        publisher: "Investor.gov / U.S. SEC",
        title: "Exchange-Traded Funds (ETFs)",
        url: URL(string: "https://www.investor.gov/introduction-investing/investing-basics/investment-products/mutual-funds-and-exchange-traded-2")!,
        summary: "SEC explainer covering how ETFs are structured, traded, and how they differ from open-end mutual funds."
    )

    private static let investorGovAssetAllocation = InvestingEducationSource(
        id: "investorgov-asset-allocation",
        publisher: "Investor.gov / U.S. SEC",
        title: "Asset Allocation",
        url: URL(string: "https://www.investor.gov/introduction-investing/getting-started/asset-allocation")!,
        summary: "SEC overview of asset allocation, diversification, risk tolerance, and time horizon as planning inputs."
    )

    private static let investorGovFees = InvestingEducationSource(
        id: "investorgov-mutual-fund-fees",
        publisher: "Investor.gov / U.S. SEC",
        title: "Mutual Fund Fees and Expenses",
        url: URL(string: "https://www.investor.gov/introduction-investing/investing-basics/glossary/mutual-fund-fees-and-expenses")!,
        summary: "SEC glossary entry on the fee categories that compound across long investing horizons."
    )

    // ---- IRS ---------------------------------------------------------

    private static let irsIRAs = InvestingEducationSource(
        id: "irs-iras",
        publisher: "IRS",
        title: "Individual Retirement Arrangements (IRAs)",
        url: URL(string: "https://www.irs.gov/retirement-plans/individual-retirement-arrangements-iras")!,
        summary: "IRS landing page covering IRA contribution limits, deductibility, and the difference between traditional and Roth accounts."
    )

    // ---- CIRO --------------------------------------------------------

    private static let ciroFees = InvestingEducationSource(
        id: "ciro-fees-and-costs",
        publisher: "CIRO",
        title: "Fees and Costs",
        url: URL(string: "https://www.ciro.ca/office-investor/investing-basics/fees-and-costs")!,
        summary: "CIRO's investor-education page on the fee categories Canadian investors encounter — including MER and trading commissions."
    )

    private static let ciroRights = InvestingEducationSource(
        id: "ciro-investor-rights",
        publisher: "CIRO",
        title: "Know Your Rights as An Investor",
        url: URL(string: "https://www.ciro.ca/office-investor/investing-basics/know-your-rights-investor")!,
        summary: "CIRO's overview of investor rights, including suitability, KYC, and how to verify an advisor's registration."
    )

    // ---- CIPF --------------------------------------------------------

    private static let cipfHome = InvestingEducationSource(
        id: "cipf-home",
        publisher: "CIPF",
        title: "Canadian Investor Protection Fund",
        url: URL(string: "https://www.cipf.ca/")!,
        summary: "CIPF protects clients of CIRO-member firms within published coverage limits when a member firm fails."
    )

    // ---- CRA ---------------------------------------------------------

    private static let craTFSA = InvestingEducationSource(
        id: "cra-tfsa-investing",
        publisher: "CRA",
        title: "The Tax-Free Savings Account",
        url: URL(string: "https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/tax-free-savings-account.html")!,
        summary: "CRA reference page for TFSA contribution-room rules, eligibility, and reporting."
    )

    private static let craRRSP = InvestingEducationSource(
        id: "cra-rrsp-investing",
        publisher: "CRA",
        title: "RRSPs and related plans",
        url: URL(string: "https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/rrsps-related-plans.html")!,
        summary: "CRA landing page for Registered Retirement Savings Plans and related registered accounts."
    )

    // MARK: - United States lessons

    private static let unitedStatesLessons: [InvestingEducationLesson] = [
        InvestingEducationLesson(
            id: "us-index-funds",
            region: .unitedStates,
            title: "What an index fund is",
            whatItIs: "An index fund is a mutual fund or ETF designed to track a published market index, holding the underlying components in roughly the index's weights. The SEC explains the structure and the tracking objective directly.",
            whyItMatters: "Index funds are a low-effort way to learn how diversification across many holdings differs from owning a single stock. The fund's prospectus and the SEC's investor-education pages are the right starting reference.",
            whatToReviewNext: [
                "Open the SEC's Mutual Funds and ETFs page and read how index funds track an index.",
                "Look up a specific index fund's prospectus on its issuer's site to see the actual holdings list.",
                "Note the difference between the index the fund tracks and the index's underlying methodology document.",
            ],
            sources: [investorGovIndexFunds],
            escalationNote: nil
        ),
        InvestingEducationLesson(
            id: "us-etfs-vs-mutual-funds",
            region: .unitedStates,
            title: "ETFs and mutual funds at a high level",
            whatItIs: "ETFs trade on exchanges throughout the day at market prices; open-end mutual funds price once a day at net asset value. Both can be index-tracking or actively managed; the SEC covers each structure separately.",
            whyItMatters: "Trading mechanics, pricing cadence, and tax treatment differ between the two structures. Reading the SEC pages first sets a fair baseline before reading any one fund's marketing material.",
            whatToReviewNext: [
                "Read the SEC's ETF page and the SEC's Mutual Funds and ETFs page back-to-back.",
                "Note which structure (ETF vs. open-end mutual fund) a fund you encounter actually uses.",
                "Look up the fund's bid/ask spread (ETF) or its NAV calculation cadence (mutual fund) before judging its cost.",
            ],
            sources: [investorGovETFs, investorGovIndexFunds],
            escalationNote: nil
        ),
        InvestingEducationLesson(
            id: "us-asset-allocation",
            region: .unitedStates,
            title: "Asset allocation, diversification, and time horizon",
            whatItIs: "Asset allocation is how a portfolio is split across asset categories (stocks, bonds, cash, others). Diversification is the spread within each category. The SEC frames both as planning inputs that depend on a personal risk tolerance and time horizon.",
            whyItMatters: "Reading the SEC's framing first prevents collapsing 'what should I buy?' into a one-line answer. The page is explicit that allocation is personal — NomadFi cannot decide it for you.",
            whatToReviewNext: [
                "Read the SEC's Asset Allocation page in full.",
                "Write down your honest time horizon for the money you are considering investing.",
                "Note that the SEC does not recommend a specific allocation — it lists factors to weigh.",
            ],
            sources: [investorGovAssetAllocation],
            escalationNote: "Cross-border situations (residency changes, multi-jurisdiction tax exposure) often interact with allocation decisions. A registered investment adviser is the right escalation when those interactions matter."
        ),
        InvestingEducationLesson(
            id: "us-fund-fees",
            region: .unitedStates,
            title: "Fund fees and expenses",
            whatItIs: "Mutual funds and ETFs charge fees through the expense ratio, plus potential sales loads or transaction costs. The SEC's glossary entry catalogues each category and how it surfaces in disclosures.",
            whyItMatters: "Fees compound across long horizons. Reviewing the SEC's categories first helps when reading a fund's prospectus or fact sheet so the cost picture is whole, not partial.",
            whatToReviewNext: [
                "Open the SEC's Mutual Fund Fees and Expenses glossary entry.",
                "Locate the expense-ratio line on a fund's prospectus or fact sheet.",
                "Note any sales-load or 12b-1 fees the SEC describes that may apply.",
            ],
            sources: [investorGovFees],
            escalationNote: nil
        ),
        InvestingEducationLesson(
            id: "us-ira-basics",
            region: .unitedStates,
            title: "IRA basics",
            whatItIs: "An Individual Retirement Arrangement (IRA) is a tax-advantaged account. The IRS publishes the contribution limits, the difference between traditional and Roth IRAs, and deductibility rules.",
            whyItMatters: "IRA rules interact with U.S. tax residency and earned-income definitions, both of which matter for cross-border earners. The IRS page is the right starting reference before any product page.",
            whatToReviewNext: [
                "Open the IRS Individual Retirement Arrangements (IRAs) page.",
                "Note the current-year contribution limit listed by the IRS.",
                "Read the high-level distinction between traditional and Roth contributions.",
            ],
            sources: [irsIRAs],
            escalationNote: "Cross-border earners often have non-trivial IRA eligibility and reporting questions. A cross-border-tax professional is the right escalation when residency or earned-income status is unclear."
        ),
    ]

    private static let unitedStatesChecklist = InvestingEducationChecklist(
        region: .unitedStates,
        title: "Investing literacy starter",
        items: [
            InvestingEducationChecklistItem(
                id: "us-read-mfetf",
                text: "Read the SEC's Mutual Funds and ETFs page on Investor.gov."
            ),
            InvestingEducationChecklistItem(
                id: "us-read-allocation",
                text: "Read the SEC's Asset Allocation page on Investor.gov."
            ),
            InvestingEducationChecklistItem(
                id: "us-read-fees",
                text: "Read the SEC's Mutual Fund Fees and Expenses glossary entry."
            ),
            InvestingEducationChecklistItem(
                id: "us-read-iras",
                text: "Read the IRS landing page for Individual Retirement Arrangements (IRAs)."
            ),
        ],
        escalationNote: "Education only. Not a substitute for a registered investment adviser. NomadFi does not recommend specific funds or accounts."
    )

    // MARK: - Canada lessons

    private static let canadaLessons: [InvestingEducationLesson] = [
        InvestingEducationLesson(
            id: "ca-fees-and-costs",
            region: .canada,
            title: "Investing fees and costs in Canada",
            whatItIs: "CIRO publishes a plain-language explainer covering the fee categories Canadian investors encounter — Management Expense Ratio (MER), trading commissions, account fees, and trailing fees.",
            whyItMatters: "Fee categories vary by product and dealer. Reading CIRO's page first makes a fund-fact-sheet or account statement easier to evaluate without leaning on any one firm's marketing copy.",
            whatToReviewNext: [
                "Open CIRO's Fees and Costs page in full.",
                "Locate the MER line on a Canadian mutual-fund fact sheet.",
                "Compare the fee categories CIRO lists against any account-opening paperwork.",
            ],
            sources: [ciroFees],
            escalationNote: nil
        ),
        InvestingEducationLesson(
            id: "ca-investor-rights",
            region: .canada,
            title: "Know your rights as an investor",
            whatItIs: "CIRO publishes an investor-rights overview covering Know-Your-Client (KYC), suitability, complaint handling, and how to verify an advisor's registration before working with them.",
            whyItMatters: "Verifying registration and understanding suitability obligations is the baseline before considering any specific product. CIRO's page is the regulator's own framing of those expectations.",
            whatToReviewNext: [
                "Open CIRO's Know Your Rights as an Investor page.",
                "Use CIRO's advisor-search tool to confirm registration before working with anyone new.",
                "Note CIRO's complaint-handling expectations in case a future issue arises.",
            ],
            sources: [ciroRights],
            escalationNote: nil
        ),
        InvestingEducationLesson(
            id: "ca-cipf-protection",
            region: .canada,
            title: "Investor protection through CIPF",
            whatItIs: "The Canadian Investor Protection Fund (CIPF) protects eligible clients of CIRO-member dealers within published coverage limits when a member firm fails.",
            whyItMatters: "Knowing what CIPF covers — and what it does not — sets a realistic baseline for evaluating where to keep accounts. CIPF's own site is the authoritative place to read the current limits.",
            whatToReviewNext: [
                "Open the CIPF homepage and read the current coverage summary.",
                "Confirm a prospective dealer is a CIRO member before opening an account.",
                "Note the categories CIPF coverage does and does not include.",
            ],
            sources: [cipfHome],
            escalationNote: nil
        ),
        InvestingEducationLesson(
            id: "ca-tfsa-basics",
            region: .canada,
            title: "TFSA basics at a high level",
            whatItIs: "The Tax-Free Savings Account (TFSA) is a registered Canadian account with annual contribution-room rules, withdrawal mechanics, and reporting set by CRA. CRA's page is the canonical reference.",
            whyItMatters: "TFSA contribution-room mistakes carry penalties, and residency status affects eligibility. Reading CRA's page before contributing keeps the planning grounded in the current-year rules.",
            whatToReviewNext: [
                "Look up your current TFSA room in CRA My Account before contributing.",
                "Read CRA's TFSA page section on residency and non-resident contributions.",
                "Note the current-year contribution limit listed by CRA.",
            ],
            sources: [craTFSA],
            escalationNote: "Cross-border residents have TFSA edge cases. A CRA-registered professional is the right escalation when residency is changing during the year."
        ),
        InvestingEducationLesson(
            id: "ca-rrsp-basics",
            region: .canada,
            title: "RRSP basics at a high level",
            whatItIs: "The Registered Retirement Savings Plan (RRSP) is a tax-deferred Canadian account. CRA publishes the deduction-limit rules, over-contribution relief, and withdrawal interaction with retirement income.",
            whyItMatters: "RRSP deduction limits change yearly and over-contribution carries a penalty. CRA's RRSP landing page is the right anchor before relying on any third-party calculator.",
            whatToReviewNext: [
                "Open CRA's RRSP page and locate your deduction limit (also visible in CRA My Account).",
                "Read CRA's section on over-contribution and the available relief.",
                "Note how RRSP contributions interact with the prior-year earned-income calculation.",
            ],
            sources: [craRRSP],
            escalationNote: "RRSP rules change each year and interact with cross-border tax treaties. A CRA-registered professional is the right escalation for non-resident situations."
        ),
    ]

    private static let canadaChecklist = InvestingEducationChecklist(
        region: .canada,
        title: "Investing literacy starter",
        items: [
            InvestingEducationChecklistItem(
                id: "ca-read-fees",
                text: "Read CIRO's Fees and Costs page."
            ),
            InvestingEducationChecklistItem(
                id: "ca-read-rights",
                text: "Read CIRO's Know Your Rights as An Investor page."
            ),
            InvestingEducationChecklistItem(
                id: "ca-read-cipf",
                text: "Read the CIPF homepage and current coverage summary."
            ),
            InvestingEducationChecklistItem(
                id: "ca-read-tfsa",
                text: "Read CRA's TFSA page and look up your current room in CRA My Account."
            ),
            InvestingEducationChecklistItem(
                id: "ca-read-rrsp",
                text: "Read CRA's RRSP page and look up your deduction limit in CRA My Account."
            ),
        ],
        escalationNote: "Education only. Not a substitute for a registered Canadian advisor or a CRA-registered professional. NomadFi does not recommend specific funds or accounts."
    )
}
