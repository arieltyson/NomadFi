// DecisionDraftKindCompletenessTests.swift
// NomadFi
//
// Pins the kind-aware completeness rules. The planner depends on
// these to decide which gaps in an interpretation become
// clarifying questions; the review screen depends on them to
// decide which gaps to surface verbatim. Locking the rules here
// prevents a future contributor from silently demanding
// purchase-shaped fields on non-purchase kinds.

import Foundation
import Testing

@testable import NomadFi

struct DecisionDraftKindCompletenessTests {

    // MARK: - Purchase-shaped kinds

    @Test("Purchase requires amount and currency — engine cannot rank without them")
    func purchaseRequiresAmountAndCurrency() {
        let required = DecisionDraftKindCompleteness.requiredFields(for: .purchase)
        #expect(required == [.amount, .currencyCode])
    }

    @Test("Travel requires amount and currency — same FX semantics as purchase")
    func travelRequiresAmountAndCurrency() {
        let required = DecisionDraftKindCompleteness.requiredFields(for: .travel)
        #expect(required == [.amount, .currencyCode])
    }

    @Test("Purchase does not require merchant or location — those are helpful, not blocking")
    func purchaseDoesNotRequireMerchantOrLocation() {
        let required = DecisionDraftKindCompleteness.requiredFields(for: .purchase)
        #expect(!required.contains(.merchantName))
        #expect(!required.contains(.locationText))
    }

    // MARK: - Non-purchase kinds

    @Test("Credit Timing requires nothing from intake — the brief picks the saved card itself")
    func creditTimingRequiresNothing() {
        let required = DecisionDraftKindCompleteness.requiredFields(for: .creditTiming)
        #expect(required.isEmpty)
    }

    @Test("Tax Education requires nothing — never demands purchase-shaped fields")
    func taxEducationRequiresNothing() {
        let required = DecisionDraftKindCompleteness.requiredFields(for: .taxEducation)
        #expect(required.isEmpty)
    }

    @Test("Investing Education requires nothing — never demands purchase-shaped fields")
    func investingEducationRequiresNothing() {
        let required = DecisionDraftKindCompleteness.requiredFields(for: .investingEducation)
        #expect(required.isEmpty)
    }

    @Test("`other` requires nothing — conservative default for unknown shapes")
    func otherRequiresNothing() {
        let required = DecisionDraftKindCompleteness.requiredFields(for: .other)
        #expect(required.isEmpty)
    }

    // MARK: - All cases covered

    @Test("Every DecisionDraftKind case has an explicit required-field decision — adding a kind without updating the rule fails this test")
    func everyKindIsCovered() {
        for kind in DecisionDraftKind.allCases {
            let required = DecisionDraftKindCompleteness.requiredFields(for: kind)
            #expect(
                required.allSatisfy(DecisionDraftInterpretationMissingField.allCases.contains),
                "Required-field set for \(kind) references unknown field(s): \(required)"
            )
        }
    }
}
