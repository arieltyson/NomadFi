import SwiftData
import SwiftUI

struct FiBotMonitoringView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.hostedBanking) private var banking
    @State private var status: HostedFiBotStatus?
    @State private var settings = HostedFiBotSettings()
    @State private var consent = false
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("Hosted FiBot checks") {
                Text("With your permission, NomadFi stores your confirmed cash plan, scheduled income, bills, reserves and scenario settings on your hosted account. A separate service checks it after bank syncs and scheduled checks. It has no access to bank credentials, and no plan is sent to an AI model.")
                Text("Bank changes invalidate manually confirmed cash until you review and upload the plan again. Alerts appear here when the app connects; remote push delivery is not enabled.")
                Toggle("I consent to uploading this plan for monitoring", isOn: $consent)
                Button(status?.enabled == true ? "Upload reviewed plan and settings" : "Enable monitoring with this plan") { Task { await upload() } }
                    .disabled(!consent || banking?.userID == nil)
                if status?.enabled == true {
                    Button("Stop monitoring and delete hosted FiBot data", role: .destructive) { Task { await disable() } }
                }
            }
            Section("Alert preferences") {
                Toggle("Projected cash shortfalls", isOn: category("cash_shortfall"))
                Toggle("Stale or incomplete information", isOn: category("stale_context"))
                Stepper("Quiet hours start: \(settings.quietStart):00", value: $settings.quietStart, in: 0...23)
                Stepper("Quiet hours end: \(settings.quietEnd):00", value: $settings.quietEnd, in: 0...23)
                Text("Time zone: \(settings.timeZone)").font(.caption)
                Button("Snooze alerts for seven days") {
                    settings.snoozedUntil = Date.now.addingTimeInterval(7 * 86400).ISO8601Format()
                }
                Button("Clear snooze") { settings.snoozedUntil = nil }
                Text("Save preference changes with the upload button. Notification eligibility is capped at one per day and three per week; this version displays an in-app alert feed.").font(.footnote)
            }
            Section("Current alerts") {
                ForEach(status?.alerts ?? []) { alert in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(alert.category == "cash_shortfall" ? "Review your cash plan" : "Your plan needs an update").font(.headline)
                        ForEach(alert.decision.reasons, id: \.self) { Text(FiBotPresentation.reason($0)) }
                        Text("Updated \(alert.createdAt)").font(.caption)
                        Button("Dismiss") { Task { await dismiss(alert.id) } }
                    }
                }
                if status?.alerts.isEmpty != false { Text("No current alerts. This does not establish that your plan is affordable.").foregroundStyle(.secondary) }
                Button("Refresh alerts") { Task { await refresh() } }
            }
            if let message { Section { Text(message) } }
        }
        .navigationTitle("FiBot monitoring")
        .disabled(busy)
        .task { await refresh() }
    }
    private func category(_ name: String) -> Binding<Bool> {
        .init(get: { settings.categories.contains(name) }, set: { enabled in
            settings.categories.removeAll { $0 == name }; if enabled { settings.categories.append(name) }
        })
    }
    private func refresh() async {
        guard let banking, banking.userID != nil else { message = "Sign in through Hosted Banking to manage monitoring."; return }
        busy = true; defer { busy = false }
        do {
            status = try await banking.client.fiBotStatus()
            if let value = status?.settings { settings = value }
            message = nil
        } catch { message = "The monitoring service could not be reached. Previous consent has not changed." }
    }
    private func upload() async {
        guard consent, let banking, let status else { return }
        busy = true; defer { busy = false }
        do {
            guard let session = try await banking.client.session() else { throw HostedServiceError.signInRequired }
            if let previous = try HostedFiBotConsent.load(), previous.userID != session.tokens.userID || previous.endpoint != session.endpoint {
                throw HostedServiceError.ownerChanged
            }
            let (plan, _) = try FiBotWorkspaceStore.load(in: ModelContext(modelContext.container))
            let zone = plan.timeZone
            settings.timeZone = zone.identifier
            let context = FiBotContextBuilder.build(plan: plan, on: FiBotCalendar.localDay(.now, in: zone))
            try HostedFiBotConsent(userID: session.tokens.userID, endpoint: session.endpoint).save()
            _ = try await banking.client.configureFiBot(.init(consent: true, expectedRevision: status.revision,
                context: context, policy: plan.policy, settings: settings))
            self.status = try await banking.client.fiBotStatus()
            message = "Your reviewed plan is saved for hosted checks."
        } catch { message = "The update could not be confirmed. Refresh the monitoring status before retrying." }
    }
    private func disable() async {
        guard let banking else { return }
        busy = true; defer { busy = false }
        do {
            try await HostedFiBotConsent.disableIfNeeded(using: banking)
            status = try await banking.client.fiBotStatus(); consent = false; message = "Hosted FiBot data was deleted. Your local plan remains."
        } catch { message = "Stopping monitoring could not be confirmed. Retry when the service is available." }
    }
    private func dismiss(_ id: UUID) async {
        guard let banking else { return }
        do { try await banking.client.dismissFiBotAlert(id); await refresh() }
        catch { message = "The alert could not be dismissed. Try again." }
    }
}
