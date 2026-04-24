// PlaidLinkPresenting.swift
// NomadFi
//
// Narrow seam between NomadFi's provider-neutral authorization state
// and Plaid's `LinkKit` iOS SDK. The protocol exists so:
//
// 1. The only file that imports `LinkKit` is
//    `PlaidLinkKitPresenter.swift`. The rest of the Plaid boundary
//    reasons about Link exclusively through this abstract surface.
// 2. Tests can stand in a stub presenter without dragging the SDK
//    into the test target.
//
// Callbacks are typed as `@MainActor @Sendable` because LinkKit's
// handler callbacks resolve on the main thread and NomadFi's
// `@Observable` state objects are main-actor isolated.
//
// Primary sources (for the LinkKit-backed implementation):
//   https://plaid.com/docs/link/ios/
//   https://plaid.com/docs/link/oauth/
//   https://plaid.com/docs/api/link/

import Foundation

/// Outcome the coordinator hands back to the provider adapter.
enum PlaidLinkOutcome: Sendable, Equatable {

    /// LinkKit fired `onSuccess`. `publicToken` feeds the broker's
    /// `/item/public_token/exchange`.
    case success(publicToken: String)

    /// User tapped "exit" before completing. No error; nothing to do.
    case cancelled

    /// LinkKit returned a recoverable error through `onExit`. The
    /// coordinator surfaces the message for the Settings row.
    case failed(message: String)
}

/// What the presenter needs to launch Link. Value-typed so tests can
/// construct fixtures without LinkKit's real types.
struct PlaidLinkPresentationRequest: Sendable, Equatable {
    let linkToken: String
    /// Non-nil for OAuth-capable institutions that need the
    /// universal-link redirect to reopen Link. `nil` on the first
    /// prompt; set to the inbound universal-link URL when NomadFi
    /// is relaunched by iOS.
    let receivedRedirectURI: URL?
}

/// Minimum surface the coordinator calls on the SDK wrapper.
protocol PlaidLinkPresenting: Sendable {

    /// Starts (or resumes) a Plaid Link session with the supplied
    /// token. The completion handler fires on the main actor exactly
    /// once per session. Implementations must be safe to call
    /// repeatedly; each call supersedes any previous pending
    /// session.
    @MainActor
    func present(
        _ request: PlaidLinkPresentationRequest,
        completion: @escaping @MainActor (PlaidLinkOutcome) -> Void
    )

    /// Forwards a universal-link URL to a pending Link session so
    /// LinkKit can continue an OAuth handoff. Returns `true` when
    /// LinkKit consumed the URL, `false` otherwise.
    @MainActor
    func handle(redirectURI url: URL) -> Bool
}
