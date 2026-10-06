// JurisdictionManagementView.swift
// NomadFi
//
// Native Settings surface for adding, removing, and re-homing
// jurisdictions without resetting onboarding or deleting account data.
// Pushed from Settings → Financial Setup → Jurisdictions.

import OSLog
import SwiftData
import SwiftUI

/// The jurisdiction management screen.
struct JurisdictionManagementView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var activeProfiles: [JurisdictionProfile]

    @State private var availableJurisdictions: [JurisdictionInfo] = []
    @State private var blockedRemoval: BlockedRemoval?
    @State private var errorMessage: String?

    /// Short-lived state used to show a confirmation dialog when the
    /// user attempts to remove a jurisdiction with dependent data.
    private struct BlockedRemoval: Identifiable {
        let id = UUID()
        let jurisdictionName: String
        let report: JurisdictionDependencyReport
    }

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "JurisdictionManagementView"
    )

    private var manager: JurisdictionManager {
        JurisdictionManager(modelContext: modelContext)
    }

    var body: some View {
        List {
            activeSection

            availableSection
        }
        .navigationTitle("Jurisdictions")
        .toolbarTitleDisplayMode(.inlineLarge)
        .task { await refreshAvailable() }
        .onChange(of: activeProfiles.count) { _, _ in
            Task { await refreshAvailable() }
        }
        .alert(
            "Can't Remove Yet",
            isPresented: blockedAlertBinding,
            presenting: blockedRemoval
        ) { _ in
            Button("OK", role: .cancel) { blockedRemoval = nil }
        } message: { blocked in
            Text(blockedMessage(for: blocked))
        }
        .alert(
            "Something Went Wrong",
            isPresented: errorAlertBinding,
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { message in
            Text(message)
        }
    }
}

// MARK: - Sections

private extension JurisdictionManagementView {

    var activeSection: some View {
        Section {
            ForEach(activeProfiles) { profile in
                ActiveJurisdictionRow(
                    profile: profile,
                    canRemove: activeProfiles.count > 1 && !profile.isHome,
                    onSetHome: { setHome(profile) },
                    onRemove: { attemptRemove(profile) }
                )
            }
        } header: {
            Text("Active")
        } footer: {
            Text("Your home jurisdiction is where NomadFi reports your net worth. Data attached to a jurisdiction keeps living on its own records — removing a jurisdiction never deletes your accounts, transactions, budgets, subscriptions, or tax documents.")
        }
    }

    var availableSection: some View {
        Section {
            if availableJurisdictions.isEmpty {
                ContentUnavailableView {
                    Label("All Supported Jurisdictions Added", systemImage: "globe")
                } description: {
                    Text("NomadFi currently supports \(JurisdictionInfo.supported.count) jurisdictions. Your active set already covers them.")
                }
            } else {
                ForEach(availableJurisdictions) { info in
                    AvailableJurisdictionRow(
                        info: info,
                        onAdd: { add(info) }
                    )
                }
            }
        } header: {
            Text("Available")
        } footer: {
            Text("Adding a jurisdiction lets you assign accounts, budgets, and tax documents to that country. You can remove it later when nothing is attached.")
        }
    }
}

// MARK: - Actions

private extension JurisdictionManagementView {

    func refreshAvailable() async {
        do {
            availableJurisdictions = try manager.availableJurisdictions()
        } catch {
            Self.logger.error("Failed to refresh available jurisdictions: \(error.localizedDescription, privacy: .public)")
        }
    }

    func add(_ info: JurisdictionInfo) {
        do {
            _ = try manager.addJurisdiction(with: info.id)
        } catch {
            errorMessage = error.localizedDescription
            Self.logger.error("Add failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func attemptRemove(_ profile: JurisdictionProfile) {
        do {
            try manager.removeJurisdiction(profile)
        } catch let JurisdictionManager.JurisdictionOperationError.hasDependents(report) {
            blockedRemoval = BlockedRemoval(
                jurisdictionName: profile.countryName,
                report: report
            )
        } catch JurisdictionManager.JurisdictionOperationError.cannotRemoveHome {
            errorMessage = "Pick a different home jurisdiction, then try removing this one again."
        } catch {
            errorMessage = error.localizedDescription
            Self.logger.error("Remove failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setHome(_ profile: JurisdictionProfile) {
        do {
            try manager.setHomeJurisdiction(profile)
        } catch {
            errorMessage = error.localizedDescription
            Self.logger.error("Set home failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func blockedMessage(for blocked: BlockedRemoval) -> String {
        let items = blocked.report.blockingItems.map(\.displayText).joined(separator: ", ")
        return "\(blocked.jurisdictionName) still has \(items) attached. Move or delete them first, then try again — removing a jurisdiction never deletes your financial records."
    }

    var blockedAlertBinding: Binding<Bool> {
        Binding(
            get: { blockedRemoval != nil },
            set: { if !$0 { blockedRemoval = nil } }
        )
    }

    var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

// MARK: - Rows

private struct ActiveJurisdictionRow: View {

    let profile: JurisdictionProfile
    let canRemove: Bool
    let onSetHome: () -> Void
    let onRemove: () -> Void

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Text(String.flagEmoji(for: profile.countryCode))
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                HStack(spacing: SpacingTokens.xSmall) {
                    Text(profile.countryName)
                        .font(TypographyTokens.body)

                    if profile.isHome {
                        StatusBadge(
                            label: "Home",
                            color: ColorTokens.actionTint,
                            systemImage: "house.fill"
                        )
                    }
                }

                if let currency = profile.currencyCode {
                    Text("\(currency.rawValue) • \(currency.displayName)")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            // HIG: don't show controls that do nothing. The home
            // jurisdiction can't be re-homed-to-itself, and the only
            // remaining row can't be removed — so there is nothing to
            // offer in the menu. The "Home" badge above already
            // communicates the status, so we hide the affordance
            // entirely instead of rendering an empty, disabled menu
            // that feels broken when tapped.
            if hasMenuActions {
                Menu {
                    if !profile.isHome {
                        Button {
                            onSetHome()
                        } label: {
                            Label("Set as Home", systemImage: "house")
                        }
                    }

                    if canRemove {
                        Button(role: .destructive) {
                            onRemove()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .accessibilityLabel("Actions for \(profile.countryName)")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [profile.countryName]
        if profile.isHome { parts.append("home jurisdiction") }
        if let currency = profile.currencyCode {
            parts.append("currency \(currency.rawValue)")
        }
        return parts.joined(separator: ", ")
    }

    /// True when the row has at least one actionable menu entry to
    /// show. Drives whether the trailing menu button is rendered at
    /// all — we hide it entirely rather than render an empty menu so
    /// the user never taps a control that produces no feedback.
    fileprivate var hasMenuActions: Bool {
        !profile.isHome || canRemove
    }
}

private struct AvailableJurisdictionRow: View {

    let info: JurisdictionInfo
    let onAdd: () -> Void

    var body: some View {
        Button {
            onAdd()
        } label: {
            HStack(spacing: SpacingTokens.small) {
                Text(info.flag)
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(info.name)
                        .font(TypographyTokens.body)

                    Text("\(info.currencyCode.rawValue) • \(info.currencyCode.displayName)")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Add \(info.name)")
        .accessibilityHint("Adds \(info.name) to your active jurisdictions.")
    }
}

#Preview {
    NavigationStack {
        JurisdictionManagementView()
    }
    .modelContainer(for: [
        JurisdictionProfile.self,
        Account.self,
        Transaction.self,
        Subscription.self,
        TaxDocument.self,
        Budget.self,
    ], inMemory: true)
}
