import SwiftUI

struct FiBotBriefView: View {
    let record: FiBotDecisionRecord
    let isCurrent: Bool
    let reserve: () -> Bool
    @State private var reserved = false
    @State private var reservationFailed = false
    private var decision: FiBotDecision? { try? JSONDecoder().decode(FiBotDecision.self, from: record.decisionData) }
    private var purchase: FiBotPurchase? { try? JSONDecoder().decode(FiBotPurchase.self, from: record.purchaseData) }
    private var context: FiBotFinancialContext? { try? JSONDecoder().decode(FiBotFinancialContext.self, from: record.contextData) }

    var body: some View {
        Form {
            if let decision, let purchase, let context {
                Section {
                    Text(FiBotPresentation.outcome(decision.outcome)).font(.title2.bold())
                    Text("Evaluated \(FiBotPresentation.money(purchase.allInCost)) on \(context.evaluatedOn), through \(context.horizonEnd).")
                    if !isCurrent || Date.now.timeIntervalSince(record.createdAt) > 3600 {
                        Text("This is a historical check. Reevaluate the current plan before reserving money.").foregroundStyle(.secondary)
                    }
                    ForEach(decision.reasons, id: \.self) { Text(FiBotPresentation.reason($0)) }
                }
                Section("Your records show") {
                    ForEach(context.accounts, id: \.id) { account in
                        Text(account.displayName ?? "Cash account").font(.headline)
                        LabeledContent("Accessible cash", value: FiBotPresentation.money(account.available))
                        LabeledContent("Protected reserve", value: FiBotPresentation.money(.init(account.protectedReserve, currency: account.available.currency)))
                        Text("Balance confirmed for \(account.observedOn)").font(.caption)
                    }
                    Text("\(context.flows.count) scheduled cash flows and \(context.commitments.count) existing purchase reservations.")
                }
                Section("The calculation assumes") {
                    Text("This check uses a \(decision.assumptions.incomeReductionPercent.formatted())% income reduction, \(decision.assumptions.expenseIncreasePercent.formatted())% expense increase, and \(decision.assumptions.incomeDelayDays)-day pay delay. These are planning assumptions, not research-derived safety thresholds or probabilities.")
                    Text("Income arrives after same-day outflows. Cash is checked separately for every account and currency. This result does not guarantee future outcomes.")
                    if let maximum = decision.maximumNow { LabeledContent("Maximum now within this plan", value: FiBotPresentation.money(maximum)) }
                    forecast("Baseline", points: decision.baseline, accountID: purchase.fundingAccountID)
                    forecast("Stress scenario", points: decision.stress, accountID: purchase.fundingAccountID)
                    Text("Rule version: \(decision.policyVersion)").font(.caption)
                }
                if decision.outcome == .affordable && isCurrent && !reserved && Date.now.timeIntervalSince(record.createdAt) <= 3600 {
                    Section {
                        Button("Reserve this amount for seven days") {
                            reserved = reserve(); reservationFailed = !reserved
                        }
                        Text("This records your intention so another check cannot spend the same money. It does not make a purchase or move funds.").font(.footnote)
                    }
                }
                Section("Research supports") {
                    Text("Research informs the planning principles. It does not prove this individual purchase is safe.")
                    ForEach(decision.evidenceIDs, id: \.self) { id in
                        if let evidence = FiBotEvidenceRegistry.evidence(for: id) {
                            Link(evidence.title, destination: evidence.url)
                            Text(evidence.finding).font(.footnote)
                            Text(evidence.limits).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Section { ShareLink("Export this private decision", item: export) }
            } else { Text("This saved decision could not be read. Reevaluate your plan.") }
        }
        .navigationTitle("FiBot brief")
        .alert("Reservation not saved", isPresented: $reservationFailed) {
            Button("OK", role: .cancel) {}
        } message: { Text("The plan may have changed. Reevaluate it before reserving this purchase.") }
    }
    @ViewBuilder private func forecast(_ name: String, points: [FiBotForecastPoint], accountID: String) -> some View {
        if let low = points.filter({ $0.accountID == accountID }).min(by: { $0.remainingAfterReserve.amount < $1.remainingAfterReserve.amount }) {
            LabeledContent("\(name) low point", value: FiBotPresentation.money(low.remainingAfterReserve))
            Text("After the purchase and reserve, on \(low.date)").font(.caption)
        }
    }
    private var export: String {
        "FiBot private decision\n\(record.question)\n\(String(data: record.contextData, encoding: .utf8) ?? "")\n\(String(data: record.purchaseData, encoding: .utf8) ?? "")\n\(String(data: record.decisionData, encoding: .utf8) ?? "")"
    }
}

struct FiBotEvidenceView: View {
    var body: some View {
        List {
            Section("User interests") { Text(FiBotEvidenceRegistry.userInterestPolicy) }
            Section("Planning assumptions") { Text(FiBotEvidenceRegistry.assumptions) }
            ForEach(FiBotEvidenceRegistry.entries) { evidence in
                Section("\(evidence.id) · \(evidence.title)") {
                    Link("\(evidence.authors), \(String(evidence.year))", destination: evidence.url)
                    Text(evidence.design); Text(evidence.population)
                    Text(evidence.finding); Text(evidence.limits)
                    Text(evidence.fundingNotes).font(.footnote)
                    Text("Reviewed \(evidence.reviewedOn). \(evidence.reviewScope)").font(.footnote)
                }
            }
        }.navigationTitle("FiBot evidence")
    }
}
