import Foundation

public enum FiBotCadence: String, Codable, CaseIterable, Sendable { case once, weekly, biweekly, monthly }

public struct FiBotPlanAccount: Identifiable, Codable, Sendable {
    public var id: String
    public var name: String
    public var cash: FiBotCashAccount
    public init(id: String = UUID().uuidString, name: String, cash: FiBotCashAccount) {
        self.id = id; self.name = name; self.cash = cash
    }
}

public struct FiBotSchedule: Identifiable, Codable, Sendable {
    public var id: String
    public var label: String
    public var accountID: String
    public var money: FiBotMoney
    public var kind: FiBotFlowKind
    public var firstDate: String
    public var lastDate: String
    public var cadence: FiBotCadence
    public var confirmedOn: String
    public init(id: String = UUID().uuidString, label: String, accountID: String, money: FiBotMoney,
                kind: FiBotFlowKind, firstDate: String, lastDate: String, cadence: FiBotCadence, confirmedOn: String) {
        self.id = id; self.label = label; self.accountID = accountID; self.money = money; self.kind = kind
        self.firstDate = firstDate; self.lastDate = lastDate; self.cadence = cadence; self.confirmedOn = confirmedOn
    }
}

public struct FiBotPlan: Codable, Sendable {
    public var timeZoneIdentifier: String? = TimeZone.current.identifier
    public var accounts: [FiBotPlanAccount] = []
    public var schedules: [FiBotSchedule] = []
    public var commitments: [FiBotCommitment] = []
    public var coverage = FiBotCoverage()
    public var confirmedOn: String = ""
    public var horizonDays: Int = 90
    public var policy = FiBotPolicy()
    public var timeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? FiBotCalendar.utc.timeZone
    }
    public init() {}
}

public enum FiBotCalendar {
    public static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    public static func date(_ text: String) -> Date? {
        let formatter = formatter()
        guard text.count == 10, let date = formatter.date(from: text), formatter.string(from: date) == text else { return nil }
        return date
    }
    public static func string(_ date: Date) -> String { formatter().string(from: date) }
    public static func localDay(_ date: Date, in timeZone: TimeZone = .current) -> String {
        let value = formatter(); value.timeZone = timeZone; return value.string(from: date)
    }
    public static func localDate(_ day: String, in timeZone: TimeZone = .current) -> Date? {
        guard date(day) != nil else { return nil }
        let value = formatter(); value.timeZone = timeZone; return value.date(from: day)
    }
    public static func adding(_ days: Int, to value: String) -> String? {
        date(value).flatMap { utc.date(byAdding: .day, value: days, to: $0) }.map(string)
    }
    private static func formatter() -> DateFormatter {
        let value = DateFormatter()
        value.calendar = utc; value.timeZone = utc.timeZone; value.locale = Locale(identifier: "en_US_POSIX")
        value.dateFormat = "yyyy-MM-dd"; value.isLenient = false
        return value
    }
}

public enum FiBotContextBuilder {
    public static func build(plan: FiBotPlan, on date: String) -> FiBotFinancialContext {
        var coverage = plan.coverage
        let end = FiBotCalendar.adding(plan.horizonDays, to: date) ?? date
        var flows: [FiBotCashFlow] = []
        var valid = plan.schedules.count <= 250 && (90...366).contains(plan.horizonDays)
            && (plan.timeZoneIdentifier == nil || plan.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) != nil)
        if let confirmed = FiBotCalendar.date(plan.confirmedOn), let today = FiBotCalendar.date(date) {
            valid = valid && confirmed <= today && today.timeIntervalSince(confirmed) <= 30 * 86400
        } else { valid = false }
        for schedule in plan.schedules.prefix(250) {
            guard let first = FiBotCalendar.date(schedule.firstDate), let last = FiBotCalendar.date(schedule.lastDate),
                  let confirmed = FiBotCalendar.date(schedule.confirmedOn), let today = FiBotCalendar.date(date),
                  last >= first, confirmed <= today, today.timeIntervalSince(confirmed) <= 30 * 86400,
                  schedule.kind != .transferIn, schedule.kind != .transferOut else { valid = false; continue }
            for index in 0..<1000 {
                let occurrence: Date?
                switch schedule.cadence {
                case .once: occurrence = index == 0 ? first : nil
                case .weekly: occurrence = FiBotCalendar.utc.date(byAdding: .day, value: 7 * index, to: first)
                case .biweekly: occurrence = FiBotCalendar.utc.date(byAdding: .day, value: 14 * index, to: first)
                case .monthly: occurrence = FiBotCalendar.utc.date(byAdding: .month, value: index, to: first)
                }
                guard let occurrence, occurrence <= last else { break }
                let day = FiBotCalendar.string(occurrence)
                if day > end { break }
                if day >= date {
                    flows.append(.init(id: "\(schedule.id):\(day)", accountID: schedule.accountID, date: day,
                                       money: schedule.money, kind: schedule.kind))
                }
                if index == 999 { valid = false }
            }
        }
        if !valid { coverage = .init() }
        let accounts = plan.accounts.map { account in
            var cash = account.cash; cash.displayName = account.name; return cash
        }
        return .init(evaluatedOn: date, horizonEnd: end, accounts: accounts, flows: flows,
                     commitments: plan.commitments, coverage: coverage)
    }
}
