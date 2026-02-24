import Foundation

enum TaxCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case education = "education"
    case medical = "medical"
    case wages = "wages"
    case scholarshipIncome = "scholarship_income"
    case treatyBenefits = "treaty_benefits"
    case capitalGains = "capital_gains"
    case tuition = "tuition"
    case textbooks = "textbooks"
    case housingExpense = "housing_expense"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .education: "Education Expenses"
        case .medical: "Medical Expenses"
        case .wages: "Wages"
        case .scholarshipIncome: "Scholarship Income"
        case .treatyBenefits: "Treaty Benefits"
        case .capitalGains: "Capital Gains"
        case .tuition: "Tuition"
        case .textbooks: "Textbooks and Supplies"
        case .housingExpense: "Housing Expense"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .education: "graduationcap"
        case .medical: "cross.case"
        case .wages: "dollarsign.circle"
        case .scholarshipIncome: "scroll"
        case .treatyBenefits: "building.columns"
        case .capitalGains: "chart.line.uptrend.xyaxis"
        case .tuition: "book.closed"
        case .textbooks: "books.vertical"
        case .housingExpense: "house"
        case .other: "ellipsis.circle"
        }
    }
}
