// PlaidValidationRecorderTests.swift
// NomadFi
//
// Focused Phase 5D coverage for the DEBUG-only Plaid validation
// recorder, redactor, and Markdown writer. Every test here is
// pure — no network, no LinkKit, no Keychain.

#if DEBUG

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct PlaidValidationRecorderTests {

    // MARK: - Redactor

    @Test("Masked item handle keeps the type prefix + last four chars")
    func maskedHandleKeepsShape() {
        #expect(
            PlaidValidationRedactor.maskedItemHandle("itm_29f63c0ccff1abcd")
                == "itm_****abcd"
        )
    }

    @Test("Short or missing item handles never leak the body")
    func maskedHandleShortInput() {
        #expect(PlaidValidationRedactor.maskedItemHandle(nil) == nil)
        #expect(PlaidValidationRedactor.maskedItemHandle("  ") == nil)
        #expect(PlaidValidationRedactor.maskedItemHandle("abc") == "***")
        #expect(PlaidValidationRedactor.maskedItemHandle("abcdefg") == "*******")
    }

    @Test("Broker URLs collapse to presence flags, never to raw host / IP")
    func brokerURLPresence() {
        #expect(PlaidValidationRedactor.brokerURLPresence(from: nil) == "missing")
        #expect(
            PlaidValidationRedactor.brokerURLPresence(
                from: URL(string: "http://192.168.1.42:8787")
            ) == "configured"
        )
    }

    @Test("Redacted error strips URLs, IPs, and long hex tokens")
    func redactedErrorRedaction() {
        let raw = "Failed https://example.com/v1/call at 10.0.0.1:443 token 1234567890abcdef1234"
        let redacted = PlaidValidationRedactor.redactedError(raw)
        #expect(!redacted.contains("https://"))
        #expect(!redacted.contains("10.0.0.1"))
        #expect(!redacted.contains("1234567890abcdef1234"))
        #expect(redacted.contains("[redacted]"))
    }

    @Test("Redacted error returns 'unknown' for empty input")
    func redactedErrorEmpty() {
        #expect(PlaidValidationRedactor.redactedError(nil) == "unknown")
        #expect(PlaidValidationRedactor.redactedError("   ") == "unknown")
    }

    @Test("Institution name honours the include toggle")
    func institutionNameOptIn() {
        #expect(
            PlaidValidationRedactor.institutionName("First Platypus Bank", include: false) == nil
        )
        #expect(
            PlaidValidationRedactor.institutionName("First Platypus Bank", include: true)
                == "First Platypus Bank"
        )
        #expect(PlaidValidationRedactor.institutionName("  ", include: true) == nil)
    }

    // MARK: - Session lifecycle

    @Test("Recording while idle is a no-op — no events leak into a prior session")
    func idleRecordingIsNoOp() {
        let recorder = PlaidValidationRecorder()
        recorder.recordLinkLaunchRequested()
        recorder.recordBrokerConfigSaved(brokerURL: URL(string: "http://127.0.0.1:8787"), hasSecret: false)
        #expect(recorder.currentSession == nil)
        #expect(recorder.lastFinalizedSession == nil)
        #expect(recorder.finalizedSessionCount == 0)
    }

    @Test("startSession stamps a session_started event with the schema version")
    func startSessionStampsSchemaVersion() {
        let recorder = PlaidValidationRecorder()
        recorder.startSession()
        let session = recorder.currentSession
        #expect(session?.events.count == 1)
        #expect(session?.events.first?.kind == .sessionStarted)
        #expect(
            session?.events.first?.details["schema_version"]
                == "\(PlaidValidationSession.schemaVersion)"
        )
    }

    @Test("endSession moves the session into lastFinalizedSession + bumps count")
    func endSessionFinalizes() {
        let recorder = PlaidValidationRecorder()
        recorder.startSession()
        recorder.recordLinkLaunchRequested()
        recorder.endSession(result: .pass, note: "Smooth OAuth return.")

        #expect(recorder.currentSession == nil)
        #expect(recorder.finalizedSessionCount == 1)
        let last = recorder.lastFinalizedSession
        #expect(last?.result == .pass)
        #expect(last?.note == "Smooth OAuth return.")
        #expect(last?.events.last?.kind == .sessionEnded)
    }

    // MARK: - Event recording + redaction

    @Test("Item handle event only stores the masked form")
    func itemHandleRecordMasks() {
        let recorder = PlaidValidationRecorder()
        recorder.startSession()
        recorder.recordItemHandlePersisted(rawHandle: "itm_29f63c0ccff1abcd")
        let event = recorder.currentSession?.events.last
        #expect(event?.kind == .itemHandlePersisted)
        let masked = event?.details["masked_item_handle"]
        #expect(masked == "itm_****abcd")
        #expect(masked?.contains("29f63c0ccff1") == false)
    }

    @Test("Institution event honours the include-institution-name toggle")
    func institutionRedactionHonoursToggle() {
        let recorder = PlaidValidationRecorder()
        recorder.startSession()
        recorder.recordInstitutionObserved(displayName: "Royal Bank of Canada")
        var event = recorder.currentSession?.events.last
        #expect(event?.details["display_name_included"] == "false")
        #expect(event?.details["display_name"] == nil)

        recorder.includesInstitutionName = true
        recorder.recordInstitutionObserved(displayName: "Royal Bank of Canada")
        event = recorder.currentSession?.events.last
        #expect(event?.details["display_name_included"] == "true")
        #expect(event?.details["display_name"] == "Royal Bank of Canada")
    }

    @Test("Reconciliation event captures the full counts")
    func reconciliationEventCounts() {
        let recorder = PlaidValidationRecorder()
        recorder.startSession()
        let result = FinancialDataReconciliationResult(
            matchedAccountsByDurableLink: 1,
            matchedAccountsByFallback: 0,
            createdAccounts: 1,
            updatedAccounts: 0,
            insertedTransactions: 4,
            skippedDuplicateTransactions: 1,
            unresolvedAmbiguousSnapshots: 0
        )
        recorder.recordReconciliationFinished(result: result)
        let event = recorder.currentSession?.events.last
        #expect(event?.details["created_accounts"] == "1")
        #expect(event?.details["inserted_transactions"] == "4")
        #expect(event?.details["skipped_duplicate_transactions"] == "1")
    }

    // MARK: - Export

    @Test("JSON export is deterministic with sorted keys and ISO-8601 timestamps")
    func exportJSONIsDeterministic() throws {
        let clock: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_714_300_000) }
        let recorder = PlaidValidationRecorder(clock: clock, appVersion: "1.0 (1)")
        recorder.startSession()
        recorder.recordLinkLaunchRequested()
        recorder.endSession(result: PlaidValidationSession.Result.pass)

        let data = try #require(try recorder.exportJSON())
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"schema_version\" : 1"))
        #expect(text.contains("\"result\" : \"pass\""))
        #expect(text.contains("2024-04-28T"))
        // Sorted keys — "app_version" comes alphabetically before "schema_version".
        let appVersionRange = text.range(of: "\"app_version\"")
        let schemaVersionRange = text.range(of: "\"schema_version\"")
        if let appVersionRange, let schemaVersionRange {
            #expect(appVersionRange.lowerBound < schemaVersionRange.lowerBound)
        } else {
            Issue.record("Missing JSON keys")
        }
    }

    @Test("Markdown export contains a criterion-5 self-assessment block")
    func markdownExportHasCriterion5Block() {
        let clock: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_714_300_000) }
        let recorder = PlaidValidationRecorder(clock: clock, appVersion: "1.0 (1)")
        recorder.startSession()
        recorder.recordBrokerHealthChecked(
            reachable: true,
            env: "sandbox",
            requiresSecret: true,
            redirectConfigured: true
        )
        recorder.recordLinkLaunchRequested()
        recorder.recordUniversalLinkObserved(host: "nomadfi-app.github.io")
        recorder.recordPublicTokenExchanged(success: true)
        recorder.recordItemHandlePersisted(rawHandle: "itm_29f63c0ccff1abcd")
        recorder.recordReconciliationFinished(
            result: FinancialDataReconciliationResult(
                matchedAccountsByDurableLink: 0,
                matchedAccountsByFallback: 0,
                createdAccounts: 1,
                updatedAccounts: 0,
                insertedTransactions: 5,
                skippedDuplicateTransactions: 0,
                unresolvedAmbiguousSnapshots: 0
            )
        )
        recorder.endSession(result: PlaidValidationSession.Result.pass)

        let markdown = recorder.exportMarkdown()
        #expect(markdown?.contains("# NomadFi Plaid Sandbox Validation Report") == true)
        #expect(markdown?.contains("## Criterion 5 self-assessment") == true)
        #expect(markdown?.contains("Broker reachable: yes") == true)
        #expect(markdown?.contains("Public-token exchanged: yes") == true)
        #expect(markdown?.contains("Item handle persisted: yes") == true)
        #expect(markdown?.contains("Result: pass") == true)
        // Masking reaches the export.
        #expect(markdown?.contains("itm_****abcd") == true)
        #expect(markdown?.contains("29f63c0ccff1") == false)
    }

    @Test("Broker reachability is inferred from successful exchange + sync when no health check ran")
    func brokerReachabilityInferredFromExchangeAndSync() {
        let clock: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_714_300_000) }
        let recorder = PlaidValidationRecorder(clock: clock, appVersion: "1.0 (1)")
        recorder.startSession()
        // Skip the health check entirely — emulate the April 2026
        // first-real-device run that went straight from Link to sync.
        recorder.recordLinkLaunchRequested()
        recorder.recordPublicTokenExchanged(success: true)
        recorder.recordItemHandlePersisted(rawHandle: "itm_aaaa1111bbbb2222")
        recorder.recordReconciliationFinished(
            result: FinancialDataReconciliationResult(
                matchedAccountsByDurableLink: 0,
                matchedAccountsByFallback: 0,
                createdAccounts: 10,
                updatedAccounts: 0,
                insertedTransactions: 48,
                skippedDuplicateTransactions: 0,
                unresolvedAmbiguousSnapshots: 0
            )
        )
        // syncFinished requires a `FinancialDataSyncReport`; the
        // simplest deterministic shape:
        recorder.recordSyncFinished(
            report: FinancialDataSyncReport(
                accountSnapshots: [],
                transactionSnapshots: [],
                outcomes: [],
                completedAt: Date(timeIntervalSince1970: 1_714_300_000)
            )
        )
        recorder.endSession(result: PlaidValidationSession.Result.pass)

        let markdown = recorder.exportMarkdown()
        #expect(
            markdown?.contains(
                "Broker reachable: yes (inferred from successful exchange/sync)"
            ) == true
        )
    }

    @Test("Health-check verification still wins the broker-reachability label")
    func brokerReachabilityHealthCheckLabel() {
        #expect(
            PlaidValidationMarkdownWriter.brokerReachableLabel(
                healthVerified: true,
                exchangeSucceeded: false,
                syncSucceeded: false
            ) == "yes (verified by health check)"
        )
    }

    @Test("Broker reachability reports 'no' only when there is genuinely no signal")
    func brokerReachabilityFallsBackToNo() {
        #expect(
            PlaidValidationMarkdownWriter.brokerReachableLabel(
                healthVerified: false,
                exchangeSucceeded: false,
                syncSucceeded: false
            ) == "no"
        )
    }

    @Test("Markdown export renders empty-event sessions without crashing")
    func markdownExportHandlesEmptyEvents() {
        let clock: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_714_300_000) }
        let recorder = PlaidValidationRecorder(clock: clock, appVersion: "1.0 (1)")
        recorder.startSession()
        // Immediately discard: one auto-generated `session_started`
        // event remains, so the events table isn't truly empty.
        recorder.endSession(result: PlaidValidationSession.Result.inconclusive)
        let markdown = recorder.exportMarkdown()
        #expect(markdown?.contains("| 1 |") == true)
        #expect(markdown?.contains("Result: inconclusive") == true)
    }

    // MARK: - Copy guard

    @Test("Nothing the recorder writes claims production coverage or contains raw secrets")
    func copyGuardAcrossExports() {
        let recorder = PlaidValidationRecorder(
            clock: { Date(timeIntervalSince1970: 1_714_300_000) },
            appVersion: "1.0 (1)"
        )
        recorder.startSession()
        recorder.includesInstitutionName = true
        recorder.recordBrokerConfigSaved(
            brokerURL: URL(string: "http://192.168.1.42:8787"),
            hasSecret: true
        )
        recorder.recordBrokerHealthChecked(
            reachable: false,
            failureReason: "refresh failed while hitting http://192.168.1.42:8787/health"
        )
        recorder.recordInstitutionObserved(displayName: "Royal Bank of Canada")
        recorder.recordItemHandlePersisted(rawHandle: "itm_29f63c0ccff1abcd")
        recorder.endSession(result: .fail)

        let markdown = recorder.exportMarkdown()
        let forbidden = [
            "192.168.1.42",
            "29f63c0ccff1",
            "all your banks",
            "all your cards",
            "production rollout",
        ]
        for phrase in forbidden {
            #expect(
                markdown?.localizedCaseInsensitiveContains(phrase) == false,
                "Forbidden phrase leaked into Markdown export: \(phrase)"
            )
        }
    }
}

#endif
