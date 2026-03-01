// AddSubscriptionView.swift
// NomadFi
//
// Manual subscription entry form for services not detected
// automatically from transaction history.

import SwiftData
import SwiftUI

/// A form for manually adding a subscription the user wants to track.
///
/// Pre-populates with sensible defaults and provides pickers for
/// currency, frequency, and jurisdiction.
struct AddSubscriptionView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @State private var saveCount = 0
    @State private var serviceName = ""
    @State private var amount: Double = 0
    @State private var currencyCode: CurrencyCode = .usd
    @State private var frequency: BillingFrequency = .monthly
    @State private var nextRenewalDate: Date = .now
    @State private var jurisdiction = ""

    var body: some View {
        NavigationStack {
            Form {
                serviceSection
                billingSection
                regionSection
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSubscription()
                        saveCount += 1
                        dismiss()
                    }
                    .bold()
                    .disabled(serviceName.isEmpty || amount <= 0)
                }
            }
            .sensoryFeedback(.success, trigger: saveCount)
        }
    }
}

// MARK: - Sections

private extension AddSubscriptionView {

    var serviceSection: some View {
        Section("Service") {
            TextField("Service name", text: $serviceName)
                .textContentType(.organizationName)
        }
    }

    var billingSection: some View {
        Section("Billing") {
            HStack {
                Text(currencyCode.symbol)
                    .foregroundStyle(.secondary)

                TextField(
                    "Amount",
                    value: $amount,
                    format: .number.precision(.fractionLength(2))
                )
                .keyboardType(.decimalPad)
            }

            Picker("Currency", selection: $currencyCode) {
                ForEach(CurrencyCode.allCases) { code in
                    Text(code.displayName).tag(code)
                }
            }

            Picker("Frequency", selection: $frequency) {
                ForEach(BillingFrequency.allCases) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }

            DatePicker(
                "Next renewal",
                selection: $nextRenewalDate,
                displayedComponents: .date
            )
        }
    }

    var regionSection: some View {
        Section("Region") {
            Picker("Jurisdiction", selection: $jurisdiction) {
                Text("None").tag("")
                ForEach(jurisdictions) { profile in
                    Text("\(String.flagEmoji(for: profile.countryCode)) \(profile.countryName)")
                        .tag(profile.countryCode)
                }
            }
        }
    }
}

// MARK: - Helpers

private extension AddSubscriptionView {

    func saveSubscription() {
        let subscription = Subscription(
            serviceName: serviceName,
            amount: amount,
            currencyCode: currencyCode,
            frequency: frequency,
            nextRenewalDate: nextRenewalDate,
            jurisdiction: jurisdiction,
            detectedAt: .now
        )
        modelContext.insert(subscription)
    }

}

#Preview {
    AddSubscriptionView()
        .modelContainer(for: [Subscription.self, JurisdictionProfile.self], inMemory: true)
}
