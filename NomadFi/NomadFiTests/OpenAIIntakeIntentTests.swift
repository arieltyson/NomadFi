// OpenAIIntakeIntentTests.swift
// NomadFi
//
// Pins the contract of the new system-surface entry into the
// on-device AI intake flow:
//
//   • The intent runs in `.foreground(.immediate)` mode — same
//     pattern as `OpenDecisionAssistantIntent`. Voice / Shortcut
//     launches must surface the app, not silently capture or
//     analyze in the background.
//   • The intent never persists, never interprets, never ranks —
//     it is *navigation only*. Persistence happens later in the
//     in-app review screen via explicit user confirmation.
//   • The acknowledgement dialog is honest about three things:
//     the app is opening, the intake runs on device, and nothing
//     saves until the user confirms.
//   • Copy guard — the dialog never uses prohibited recommendation
//     / verified / analyzed language.

import AppIntents
import Testing

@testable import NomadFi

struct OpenAIIntakeIntentTests {

    // MARK: - Mode contract

    @Test("OpenAIIntakeIntent runs in .foreground(.immediate) — the user's purpose is to continue the flow in-app")
    func openAIIntakeIsForeground() {
        let modes = OpenAIIntakeIntent.supportedModes
        #expect(modes.contains(.foreground))
        #expect(!modes.contains(.background))
    }

    // MARK: - Metadata

    @Test("OpenAIIntakeIntent surfaces a short, action-first title")
    func titleIsShortAndActionFirst() {
        let title = String(localized: OpenAIIntakeIntent.title)
        #expect(title == "Describe a Decision")
    }

    @Test("OpenAIIntakeIntent description is honest about on-device + user-confirmed save")
    func descriptionIsHonest() {
        let raw = String(reflecting: OpenAIIntakeIntent.description)
        #expect(raw.localizedStandardContains("on-device"))
        #expect(raw.localizedStandardContains("confirm"))
    }

    // MARK: - Acknowledgement dialog

    @Test("openAIIntakeAcknowledgement dialog is honest about app open, on-device intake, and explicit save")
    func acknowledgementDialogIsHonest() {
        let dialog = DecisionAssistantIntentDialog.openAIIntakeAcknowledgement
        #expect(dialog.localizedStandardContains("Opening NomadFi"))
        #expect(dialog.localizedStandardContains("on-device"))
        #expect(
            dialog.localizedStandardContains("review")
                || dialog.localizedStandardContains("confirm")
        )
    }

    @Test("openAIIntakeAcknowledgement never uses prohibited recommendation / verified / analyzed language")
    func acknowledgementDialogCopyGuard() {
        let prohibited: [String] = [
            "best card",
            "best account",
            "best option",
            "recommended",
            "we recommend",
            "you should",
            "analyzed",
            "analysed",
            "verified",
            "guaranteed",
        ]
        let dialog = DecisionAssistantIntentDialog.openAIIntakeAcknowledgement
        for phrase in prohibited {
            #expect(
                !dialog.localizedStandardContains(phrase),
                "Banned phrase '\(phrase)' found in openAIIntakeAcknowledgement: \(dialog)"
            )
        }
    }
}
