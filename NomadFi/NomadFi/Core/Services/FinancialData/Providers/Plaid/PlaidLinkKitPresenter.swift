// PlaidLinkKitPresenter.swift
// NomadFi
//
// The *only* file in NomadFi that imports Plaid's `LinkKit` SDK, and
// it compiles in DEBUG builds only: release builds neither link nor
// embed LinkKit (see `UnavailablePlaidLinkPresenter` and the target's
// Release linker flags and "Remove LinkKit from Release" phase).
// Everything outside this file talks to the abstract
// ``PlaidLinkPresenting`` seam, so if LinkKit is unavailable at
// build time (e.g. the SPM package did not resolve on a CI runner
// without network access) the rest of the Plaid boundary still
// compiles and the app's other providers keep working.
//
// Primary sources used for this wrapper:
//   https://plaid.com/docs/link/ios/        (SDK integration)
//   https://plaid.com/docs/link/oauth/      (universal-link return path)
//   https://plaid.com/docs/api/link/         (link_token surface)
//
// OAuth notes (Plaid + Apple):
// - Plaid iOS requires an HTTPS redirect URI (not a custom URL
//   scheme). NomadFi uses
//   `https://arieltyson.github.io/nomadfi-privacy/plaid-oauth` and
//   registers it via the `com.apple.developer.associated-domains`
//   entitlement.
// - When iOS relaunches NomadFi through the universal link,
//   ``PlaidLinkCoordinator/handle(universalLink:)`` forwards the URL
//   to this presenter, which in turn calls LinkKit's
//   `handler.continue(from:)` so Link resumes the session.

#if DEBUG || HOSTED_BANKING

import Foundation
import OSLog
import SwiftUI
import UIKit

#if canImport(LinkKit)
import LinkKit
#endif

/// Production `PlaidLinkPresenting` implementation backed by the
/// official LinkKit SDK. `final class` (not a struct) because Link's
/// handler API retains a delegate-style reference for the duration
/// of the session, and the OAuth-continuation path needs stable
/// identity on that handler.
@MainActor
final class PlaidLinkKitPresenter: PlaidLinkPresenting {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "FinancialData.PlaidSandbox.Link"
    )

    #if canImport(LinkKit)
    private var pendingHandler: Handler?
    #endif

    private var pendingCompletion: ((PlaidLinkOutcome) -> Void)?

    nonisolated init() {}

    // MARK: - PlaidLinkPresenting

    func present(
        _ request: PlaidLinkPresentationRequest,
        completion: @escaping @MainActor (PlaidLinkOutcome) -> Void
    ) {
        pendingCompletion = completion

        #if canImport(LinkKit)
        // LinkKit 5.x drives OAuth redirect URI configuration through
        // the server-side `link_token` payload, not through a client-
        // side `receivedRedirectUri`. The app only needs to forward
        // universal-link returns via `Handler.resumeAfterTermination(from:)`
        // (see `handle(redirectURI:)` below).

        var config = LinkTokenConfiguration(token: request.linkToken) { [weak self] success in
            self?.deliver(.success(publicToken: success.publicToken))
        }
        config.onExit = { [weak self] exit in
            guard let self else { return }
            if let error = exit.error {
                self.deliver(.failed(message: error.errorMessage))
            } else {
                self.deliver(.cancelled)
            }
        }

        switch Plaid.create(config) {
        case .success(let handler):
            pendingHandler = handler
            if let redirect = request.receivedRedirectURI {
                handler.resumeAfterTermination(from: redirect)
            }
            guard let hostController = Self.topViewController() else {
                Self.logger.error("Plaid Link could not find a host view controller")
                deliver(.failed(message: "Unable to present Plaid Link — no active window."))
                return
            }
            handler.open(presentUsing: .viewController(hostController))
        case .failure(let error):
            Self.logger.error(
                "Plaid.create failed: \(String(describing: error), privacy: .public)"
            )
            deliver(.failed(message: "Plaid Link could not start — \(error.localizedDescription)"))
        }
        #else
        // LinkKit is not linked (tests / packaging without SPM). Fail
        // gracefully so the rest of the app keeps working.
        deliver(.failed(message: "Plaid LinkKit is not included in this build."))
        #endif
    }

    @discardableResult
    func handle(redirectURI url: URL) -> Bool {
        #if canImport(LinkKit)
        guard let handler = pendingHandler else {
            return false
        }
        handler.resumeAfterTermination(from: url)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Private

    private func deliver(_ outcome: PlaidLinkOutcome) {
        #if canImport(LinkKit)
        pendingHandler = nil
        #endif
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(outcome)
    }

    /// Finds the top-most view controller on an active window scene
    /// so LinkKit has somewhere to present its UI. Uses
    /// `UIApplication.connectedScenes` (iOS 13+ / iOS 26-safe).
    static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return nil }
        guard let root = scene.keyWindow?.rootViewController
            ?? scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene.windows.first?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

#endif
