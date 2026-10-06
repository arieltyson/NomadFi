// UnavailablePlaidLinkPresenter.swift
// NomadFi
//
// The Plaid Link presenter in builds that ship without LinkKit.

import Foundation

/// Stands in for ``PlaidLinkKitPresenter`` in release builds, which do
/// not link Plaid's SDK. Release builds never show a Plaid Link entry
/// point; if one is ever reached, it reports the connection as
/// unavailable rather than failing silently.
struct UnavailablePlaidLinkPresenter: PlaidLinkPresenting {

    @MainActor
    func present(
        _ request: PlaidLinkPresentationRequest,
        completion: @escaping @MainActor (PlaidLinkOutcome) -> Void
    ) {
        completion(.failed(message: "Bank connections aren't available in this version of NomadFi."))
    }

    @MainActor
    func handle(redirectURI url: URL) -> Bool {
        false
    }
}
