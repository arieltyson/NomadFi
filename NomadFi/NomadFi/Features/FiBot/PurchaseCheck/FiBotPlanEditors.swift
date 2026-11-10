import SwiftUI

struct FiBotAccountEditor: View {
    @Environment(\.dismiss) private var dismiss
    var existing: FiBotPlanAccount?
    var timeZone: TimeZone = .current
    let onSave: (FiBotPlanAccount) -> Void
    @State private var name = ""
    @State private var currency = "CAD"
    @State private var balance = ""
    @State private var reserve = ""
    @State private var observed = Date.now
    @State private var confirmed = false

    var body: some View {
        Form {
            TextField("Account name", text: $name)
            Picker("Currency", selection: $currency) { Text("CAD").tag("CAD"); Text("USD").tag("USD") }
                .disabled(existing != nil)
            TextField("Cash available after holds and shared ownership", text: $balance).keyboardType(.decimalPad)
            TextField("Protected reserve", text: $reserve).keyboardType(.decimalPad)
            DatePicker("Balance observed", selection: $observed, in: ...Date.now, displayedComponents: .date)
            Toggle("I verified these accessible funds and reserve", isOn: $confirmed)
            Text("Use a checking, accessible savings or cash account. Do not include overdraft, credit limits, investments or locked deposits.").font(.footnote)
            Button("Save account") {
                guard let amount = FiBotPresentation.parse(balance), let reserve = FiBotPresentation.parse(reserve) else { return }
                let id = existing?.id ?? UUID().uuidString
                onSave(.init(id: id, name: String(name.prefix(120)), cash: .init(id: existing?.cash.id ?? id,
                    available: .init(amount, currency: currency), protectedReserve: reserve,
                    observedOn: FiBotCalendar.localDay(observed, in: timeZone), verification: .confirmed)))
                dismiss()
            }.disabled(!confirmed || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                       || FiBotPresentation.parse(balance) == nil || FiBotPresentation.parse(reserve) == nil)
        }
        .navigationTitle(existing == nil ? "Accessible cash" : "Update accessible cash")
        .environment(\.timeZone, timeZone)
        .onAppear {
            guard let existing else { return }
            name = existing.name; currency = existing.cash.available.currency
            balance = NSDecimalNumber(decimal: existing.cash.available.amount).stringValue
            reserve = NSDecimalNumber(decimal: existing.cash.protectedReserve).stringValue
            observed = FiBotCalendar.localDate(existing.cash.observedOn, in: timeZone) ?? .now
        }
    }
}

struct FiBotScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let accounts: [FiBotPlanAccount]
    var existing: FiBotSchedule?
    var timeZone: TimeZone = .current
    let onSave: (FiBotSchedule) -> Void
    @State private var label = ""
    @State private var accountID = ""
    @State private var amount = ""
    @State private var kind = FiBotFlowKind.essential
    @State private var cadence = FiBotCadence.once
    @State private var firstDate = Date.now
    @State private var lastDate = Date.now.addingTimeInterval(90 * 86400)
    @State private var confirmed = false
    private let kinds: [FiBotFlowKind] = [.netIncome, .essential, .debtPayment, .discretionary, .optionalGoal]

    var body: some View {
        Form {
            TextField("Employer, bill or spending category", text: $label)
            Picker("Cash account", selection: $accountID) {
                Text("Choose an account").tag("")
                ForEach(accounts) { Text($0.name).tag($0.cash.id) }
            }
            Picker("Type", selection: $kind) { ForEach(kinds, id: \.self) { Text(FiBotPresentation.kind($0)).tag($0) } }
            TextField(kind == .netIncome ? "Net amount after withholding" : "Amount", text: $amount).keyboardType(.decimalPad)
            Picker("Repeats", selection: $cadence) {
                Text("Once").tag(FiBotCadence.once); Text("Weekly").tag(FiBotCadence.weekly)
                Text("Every two weeks").tag(FiBotCadence.biweekly); Text("Monthly").tag(FiBotCadence.monthly)
            }
            DatePicker("First date", selection: $firstDate, displayedComponents: .date)
            if cadence != .once { DatePicker("Last confirmed date", selection: $lastDate, in: firstDate..., displayedComponents: .date) }
            Toggle("Amount and dates are confirmed", isOn: $confirmed)
            Text(kind == .netIncome
                 ? "Confirm ongoing net pay and the final employment date. Exclude uncertain overtime, bonuses, gifts, refunds and loans; deduct confirmed self-employment taxes and expenses."
                 : "Schedule payments from the cash account that funds them. Card settlement reduces cash once; do not also enter the same card purchases as cash outflows.")
                .font(.footnote)
            Button("Save schedule") {
                guard let account = accounts.first(where: { $0.cash.id == accountID }), let amount = FiBotPresentation.parse(amount) else { return }
                onSave(.init(id: existing?.id ?? UUID().uuidString, label: String(label.prefix(120)), accountID: accountID,
                    money: .init(amount, currency: account.cash.available.currency), kind: kind,
                    firstDate: FiBotCalendar.localDay(firstDate, in: timeZone),
                    lastDate: FiBotCalendar.localDay(cadence == .once ? firstDate : lastDate, in: timeZone),
                    cadence: cadence, confirmedOn: FiBotCalendar.localDay(.now, in: timeZone)))
                dismiss()
            }.disabled(!confirmed || accountID.isEmpty || label.isEmpty || FiBotPresentation.parse(amount) == nil)
        }
        .navigationTitle("Income or expense")
        .environment(\.timeZone, timeZone)
        .onAppear {
            guard let existing else { return }
            label = existing.label; accountID = existing.accountID; amount = NSDecimalNumber(decimal: existing.money.amount).stringValue
            kind = existing.kind; cadence = existing.cadence
            firstDate = FiBotCalendar.localDate(existing.firstDate, in: timeZone) ?? .now
            lastDate = FiBotCalendar.localDate(existing.lastDate, in: timeZone) ?? .now
        }
    }
}

enum FiBotPresentation {
    static func parse(_ value: String) -> Decimal? {
        guard value.range(of: "^[0-9]{1,12}([.,][0-9]{1,2})?$", options: .regularExpression) != nil else { return nil }
        return Decimal(string: value.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }
    static func money(_ value: FiBotMoney) -> String { "\(value.currency) \(NSDecimalNumber(decimal: value.amount).stringValue)" }
    static func kind(_ value: FiBotFlowKind) -> String {
        switch value {
        case .netIncome: "Confirmed net income"
        case .essential: "Essential or irregular expense"
        case .debtPayment: "Debt or card payment"
        case .discretionary: "Expected variable spending"
        case .optionalGoal: "Optional savings goal"
        case .transferIn: "Transfer arriving"
        case .transferOut: "Transfer leaving"
        }
    }
    static func outcome(_ value: FiBotOutcome) -> String {
        switch value {
        case .affordable: "Affordable within this plan"
        case .affordableWithTradeoffs: "Affordable with tradeoffs"
        case .wait: "Wait or reduce the cost"
        case .needsMoreInformation: "More information needed"
        }
    }
    static func reason(_ value: String) -> String {
        let messages = [
            "confirm_90_day_or_longer_forecast": "Confirm a forecast covering 90 to 366 days.",
            "confirm_net_salary_and_pay_dates": "Confirm net income, pay dates and employment end dates.",
            "confirm_bills_and_irregular_costs": "Confirm bills and irregular costs, including rent and taxes.",
            "confirm_all_accounts_and_shared_funds": "Confirm all cash accounts and shared ownership limits.",
            "include_expected_variable_spending": "Include expected food, cash and discretionary spending.",
            "confirm_debt_payment_schedules": "Confirm every debt payment and due date.",
            "confirm_tax_fees_and_ownership_costs": "Confirm the full purchase cost and whether future costs need a longer analysis.",
            "select_accessible_cash_account": "Select an accessible cash account to fund this purchase.",
            "confirm_purchase_currency_and_all_in_amount": "Confirm a positive total in the funding account's currency.",
            "confirm_fresh_accessible_balances": "Refresh accessible balances and their observation dates.",
            "confirm_dated_cash_flows_and_extend_horizon_if_needed": "Check scheduled amounts, currencies and dates within the forecast.",
            "reconcile_purchase_commitments": "Reconcile existing purchase reservations with their payments.",
            "confirm_optional_goal_changes_before_buying": "This requires changing optional goals. Edit the plan and check again before reserving money.",
            "another_account_has_a_shortfall": "Another cash account falls below its protected funds. A surplus elsewhere does not fund it automatically.",
            "purchase_reduces_protected_cash": "This purchase would leave too little cash for the confirmed plan under at least one scenario.",
            "covers_confirmed_plan_and_stress": "The purchase fits the confirmed cash plan and displayed stress scenario.",
            "cross_currency_transfer_requires_reviewed_settlement_quote": "A cross-currency transfer needs reviewed FX costs and settlement timing.",
        ]
        return messages[value] ?? "Some plan information is invalid or unsupported. Review account identities, dates, currencies and scenario settings."
    }
}
