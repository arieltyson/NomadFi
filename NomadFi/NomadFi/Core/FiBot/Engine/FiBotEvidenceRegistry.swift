import Foundation

public struct FiBotEvidence: Identifiable, Sendable {
    public let id: String
    public let authors: String
    public let year: Int
    public let title: String
    public let url: URL
    public let design: String
    public let population: String
    public let finding: String
    public let limits: String
    public let fundingNotes: String
    public let rules: [String]
    public var reviewedOn: String { "2026-10-06" }
    public var reviewScope: String { "Primary-source claim check; independent financial-domain review pending." }
    public var correctionStatus: String { "No correction identified in the linked source during this review; ongoing surveillance required." }
}

public enum FiBotEvidenceRegistry {
    public static let version = "evidence-2026-10-06"
    public static let entries: [FiBotEvidence] = [
        .init(id: "R1", authors: "Kaiser, Lusardi, Menkhoff and Urban", year: 2022,
              title: "Financial Education Affects Financial Knowledge and Downstream Behaviors",
              url: URL(string: "https://www.nber.org/papers/w27057")!,
              design: "Meta-analysis of 76 randomized experiments", population: "Multiple countries; over 160,000 participants",
              finding: "Financial education improves knowledge and behavior on average.",
              limits: "Effects vary. These programs did not test FiBot or establish LLM advice quality.",
              fundingNotes: "Working paper acknowledges DFG CRC TRR 190 funding; this is not a complete conflict audit.", rules: ["explain_calculations"]),
        .init(id: "R2", authors: "Karlan, McConnell, Mullainathan and Zinman", year: 2016,
              title: "Getting to the Top of Mind: How Reminders Increase Saving",
              url: URL(string: "https://www.nber.org/papers/w16205")!,
              design: "Three randomized field experiments", population: "New savings account holders in Bolivia, Peru and the Philippines",
              finding: "Goal-salient reminders supported saving in these experiments.",
              limits: "Notification effects depend on context. FiBot reminders require their own evaluation.",
              fundingNotes: "Paper acknowledges Gates Foundation, CGAP, Ford Foundation, Boston College, Netspar and NSF funding.", rules: ["optional_reminders"]),
        .init(id: "R3", authors: "Sussman and Alter", year: 2012,
              title: "The Exception Is the Rule",
              url: URL(string: "https://doi.org/10.1086/665833")!,
              design: "Seven behavioral studies", population: "Consumer budgeting study participants; generalizability is limited",
              finding: "People can underestimate exceptional expenses when treating each as a separate exception.",
              limits: "Supports examining irregular costs together, not a universal spending threshold.",
              fundingNotes: "Funding and conflicts were not independently established in this source review.", rules: ["include_irregular_costs"]),
        .init(id: "R4", authors: "JPMorgan Chase Institute", year: 2019,
              title: "Weathering Volatility 2.0",
              url: URL(string: "https://www.jpmorganchase.com/institute/all-topics/household-financial-health/report-weathering-volatility-2-a-monthly-stress-test-to-guide-saving")!,
              design: "Observational administrative data and modeled cash buffers", population: "U.S. Chase account holders",
              finding: "Income and expenses vary over time, with substantial differences between households.",
              limits: "Institution-specific observations do not establish a universal reserve or FiBot's scenario percentages.",
              fundingNotes: "Published by a bank-affiliated research institute using bank records.", rules: ["stress_cash_flow"]),
        .init(id: "R5", authors: "CFPB Office of Research", year: 2022,
              title: "Emergency Savings and Financial Security",
              url: URL(string: "https://www.consumerfinance.gov/data-research/research-reports/emergency-savings-financial-security-insights-from-making-ends-meet-survey-and-consumer-credit-panel/")!,
              design: "Linked survey and credit-panel analysis", population: "U.S. consumers in the Making Ends Meet survey",
              finding: "Savings levels are associated with different financial outcomes; income and obligations constrain saving.",
              limits: "Association is not causal proof. No fixed reserve amount follows from this report.",
              fundingNotes: "U.S. public-agency research; no independent conflict audit performed.", rules: ["protect_confirmed_reserve"]),
        .init(id: "R6", authors: "Consumer Financial Protection Bureau", year: 2015,
              title: "Financial Well-Being Scale",
              url: URL(string: "https://www.consumerfinance.gov/data-research/research-reports/financial-well-being-scale/")!,
              design: "Questionnaire development and psychometric validation", population: "U.S. consumers",
              finding: "A scored self-report questionnaire measures perceived financial security and choice.",
              limits: "Not an account-derived score, affordability test, or validated Canadian comparison by default.",
              fundingNotes: "U.S. public-agency research; use the official questionnaire and scoring procedure.", rules: ["optional_pilot_measurement"]),
    ]
    public static func evidence(for id: String) -> FiBotEvidence? { entries.first { $0.id == id } }
    public static let assumptions = "The 90-day minimum horizon, two-day balance window, 10% income reduction, 10% expense increase and three-day payroll delay are configurable planning assumptions. They are not research-derived safety thresholds or probabilities."
    public static let userInterestPolicy = "Protect essential payments and confirmed reserves. Never use reward points, commissions, engagement, credit limits or a request for reassurance to increase affordability. Never execute a financial transaction."
}
