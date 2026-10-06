import SwiftData
import SwiftUI

struct FiBotWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bankAccounts: [Account]
    @State private var context: ModelContext?
    @State private var plan = FiBotPlan()
    @State private var revision: UUID?
    @State private var records: [FiBotDecisionRecord] = []
    @State private var question = ""
    @State private var amount = ""
    @State private var fundingID = ""
    @State private var costsComplete = false
    @State private var selected: FiBotDecisionRecord?
    @State private var error: String?
    @State private var deleting = false

    var body: some View {
        Form {
            Section {
                Text("FiBot checks an immediate cash purchase against your confirmed income, bills and reserves. Review your plan before relying on a result.")
                NavigationLink("Financial plan") { planEditor }
            }
            Section("Can I afford this?") {
                TextField("What are you considering?", text: $question, axis: .vertical).lineLimit(1...3)
                Picker("Pay from", selection: $fundingID) {
                    Text("Choose an account").tag("")
                    ForEach(plan.accounts) { Text($0.name).tag($0.cash.id) }
                }
                TextField("Total including tax and fees", text: $amount).keyboardType(.decimalPad)
                Toggle("This is the complete one-time cost", isOn: $costsComplete)
                Text("For financing, subscriptions, future ownership costs or currency conversion, this one-time check cannot establish affordability.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Check my plan", action: evaluate)
                    .disabled(fundingID.isEmpty || money(amount) == nil)
            }
            Section("Shared purchase reservations") {
                if plan.commitments.isEmpty { Text("No money reserved for proposed purchases.").foregroundStyle(.secondary) }
                ForEach(plan.commitments, id: \.id) { commitment in
                    VStack(alignment: .leading) {
                        Text(FiBotPresentation.money(commitment.money))
                        Text("Expires after \(commitment.expiresOn)").font(.caption)
                        Button("Release reservation") {
                            plan.commitments.removeAll { $0.id == commitment.id }
                            plan.coverage.accountsComplete = false
                            save()
                        }
                    }
                }
                Text("After a purchase posts, refresh the accessible balance and remove its reservation. Releasing a reservation requires confirming account coverage again.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Decision history") {
                if records.isEmpty { Text("Your checks will appear here.").foregroundStyle(.secondary) }
                ForEach(records) { record in
                    Button { selected = record } label: {
                        VStack(alignment: .leading) {
                            Text(record.question.isEmpty ? "Purchase check" : record.question)
                            Text(record.createdAt, style: .date).font(.caption)
                            if record.planRevision != revision { Text("Plan changed · check again").font(.caption) }
                        }
                    }
                    .swipeActions { Button("Delete", role: .destructive) { remove(record) } }
                }
                Text("Keeps up to 50 checks for 30 days. Past decisions describe the inputs available at that time.").font(.footnote)
            }
            Section {
                NavigationLink("Research and assumptions") { FiBotEvidenceView() }
                ShareLink("Export FiBot plan", item: exportPlan)
                Button("Delete FiBot plan and history", role: .destructive) { deleting = true }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }
        .navigationTitle("FiBot")
        .task { context = ModelContext(modelContext.container); context?.autosaveEnabled = false; reload() }
        .sheet(item: $selected) { record in
            NavigationStack {
                FiBotBriefView(record: record, isCurrent: record.planRevision == revision) {
                    perform { context in try FiBotWorkspaceStore.reserve(record, in: context) }
                }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selected = nil } } }
            }
        }
        .confirmationDialog("Delete your FiBot plan and all saved checks?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete FiBot data", role: .destructive) { perform { try FiBotWorkspaceStore.erase(in: $0) } }
        }
    }

    private var planEditor: some View {
        Form {
            Section("Review your bank records") {
                if bankAccounts.isEmpty { Text("No bank accounts are stored on this phone.") }
                ForEach(bankAccounts) { account in
                    VStack(alignment: .leading) {
                        Text(account.name)
                        Text(account.primaryAmountLabel.text).font(.caption)
                    }
                }
                Text("Bank balances are reference information. Enter only cash you can actually access, after holds and shared ownership limits. Credit limits and investments are excluded.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Accessible cash and protected reserves") {
                ForEach(plan.accounts) { account in
                    NavigationLink(account.name) {
                        FiBotAccountEditor(existing: account) { value in
                            if let index = plan.accounts.firstIndex(where: { $0.id == value.id }) { plan.accounts[index] = value }
                            invalidateCoverage(); save()
                        }
                    }
                    .swipeActions { Button("Delete", role: .destructive) {
                        plan.accounts.removeAll { $0.id == account.id }; invalidateCoverage(); save()
                    } }
                }
                NavigationLink("Add accessible cash account") {
                    FiBotAccountEditor { plan.accounts.append($0); invalidateCoverage(); save() }
                }
            }
            Section("Net pay, bills and expected spending") {
                ForEach(plan.schedules) { schedule in
                    NavigationLink {
                        FiBotScheduleEditor(accounts: plan.accounts, existing: schedule) { value in
                            if let index = plan.schedules.firstIndex(where: { $0.id == value.id }) { plan.schedules[index] = value }
                            invalidateCoverage(); save()
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(schedule.label)
                            Text("\(FiBotPresentation.money(schedule.money)) · \(FiBotPresentation.kind(schedule.kind))").font(.caption)
                        }
                    }
                    .swipeActions { Button("Delete", role: .destructive) {
                        plan.schedules.removeAll { $0.id == schedule.id }; invalidateCoverage(); save()
                    } }
                }
                NavigationLink("Add confirmed income or expense") {
                    FiBotScheduleEditor(accounts: plan.accounts) { plan.schedules.append($0); invalidateCoverage(); save() }
                }.disabled(plan.accounts.isEmpty)
                Text("Include food, irregular costs, cash spending, taxes and card payments. Enter net salary only; a past deposit does not confirm future employment. Never include a loan, refund or transfer as salary.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Confirm coverage") {
                Stepper("Forecast: \(plan.horizonDays) days", value: $plan.horizonDays, in: 90...366, step: 1)
                Toggle("Net income and pay dates are confirmed", isOn: $plan.coverage.incomeConfirmed)
                Toggle("Bills and irregular costs are included", isOn: $plan.coverage.obligationsConfirmed)
                Toggle("All cash accounts and access limits are included", isOn: $plan.coverage.accountsComplete)
                Toggle("Expected variable spending is included", isOn: $plan.coverage.spendingIncluded)
                Toggle("All debt payments are scheduled", isOn: $plan.coverage.debtPaymentsIncluded)
                Button("Save coverage confirmation") { plan.confirmedOn = FiBotCalendar.string(.now); save() }
                Text("Confirmation lasts 30 days. Accessible balances must be confirmed within two days. Update your plan whenever pay, spending, bills or employment changes.").font(.footnote)
            }
            Section("Stress scenario") {
                Text(FiBotEvidenceRegistry.assumptions).font(.footnote)
                Stepper("Pay delay: \(plan.policy.incomeDelayDays) days", value: $plan.policy.incomeDelayDays, in: 0...30)
                TextField("Income reduction (%)", value: $plan.policy.incomeReductionPercent, format: .number).keyboardType(.decimalPad)
                TextField("Expense increase (%)", value: $plan.policy.expenseIncreasePercent, format: .number).keyboardType(.decimalPad)
                Button("Save scenario") { save() }
            }
        }
        .navigationTitle("Financial plan")
    }

    private var exportPlan: String { (try? JSONEncoder().encode(plan)).flatMap { String(data: $0, encoding: .utf8) } ?? "" }
    private func invalidateCoverage() { plan.coverage = .init(); plan.confirmedOn = "" }
    private func money(_ text: String) -> Decimal? { FiBotPresentation.parse(text) }
    private func save() { perform { try FiBotWorkspaceStore.save(plan, in: $0) } }
    private func remove(_ record: FiBotDecisionRecord) { perform { $0.delete(record); try $0.save() } }
    private func evaluate() {
        guard let account = plan.accounts.first(where: { $0.cash.id == fundingID }), let value = money(amount) else { return }
        perform { context in
            try FiBotWorkspaceStore.save(plan, in: context)
            selected = try FiBotWorkspaceStore.evaluate(question: question,
                purchase: .init(fundingAccountID: fundingID, allInCost: .init(value, currency: account.cash.available.currency),
                                costsComplete: costsComplete), in: context)
        }
    }
    @discardableResult private func perform(_ action: (ModelContext) throws -> Void) -> Bool {
        guard let context else { return false }
        do { try action(context); error = nil; reload(); return true }
        catch { context.rollback(); self.error = "The change could not be saved. Reopen your plan and check again."; reload(); return false }
    }
    private func reload() {
        guard let context else { return }
        do {
            (plan, revision) = try FiBotWorkspaceStore.load(in: context)
            records = try context.fetch(FetchDescriptor<FiBotDecisionRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            for row in records where Date.now.timeIntervalSince(row.createdAt) > 30 * 86400 { context.delete(row) }
            try context.save()
            records = try context.fetch(FetchDescriptor<FiBotDecisionRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        } catch { self.error = "Your saved FiBot plan could not be read. No data was replaced." }
    }
}
