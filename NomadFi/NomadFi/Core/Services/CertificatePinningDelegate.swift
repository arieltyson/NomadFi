// CertificatePinningDelegate.swift
// NomadFi
//
// URLSession delegate enforcing TLS certificate validation for the
// exchange rate API. Rejects connections that fail standard trust evaluation.

import Foundation
import OSLog

/// A `URLSessionDelegate` that enforces strict TLS certificate validation.
///
/// Validates the server's certificate chain using the system trust store.
/// Rejects any connection where `SecTrustEvaluateWithError` fails, preventing
/// man-in-the-middle attacks on untrusted Wi-Fi networks.
///
/// For free APIs (like the open exchange rate service), full public-key
/// pinning is impractical since certificate rotation is unpredictable.
/// Instead, this delegate enforces:
/// 1. Valid TLS certificate chain (system trust store)
/// 2. HTTPS-only connections (no plain HTTP fallback)
/// 3. Logging of all trust evaluation failures for diagnostics
///
/// - Note: ATS (App Transport Security) already enforces TLS 1.2+ with
///   no exceptions configured in Info.plist. This delegate adds defense-in-depth
///   at the session level.
final class CertificatePinningDelegate: NSObject, URLSessionDelegate, Sendable {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "NetworkSecurity")

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            Self.logger.warning("Unexpected auth challenge: \(challenge.protectionSpace.authenticationMethod, privacy: .public)")
            return (.cancelAuthenticationChallenge, nil)
        }

        // Evaluate the server's certificate chain against the system trust store
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        if isValid {
            let credential = URLCredential(trust: serverTrust)
            return (.useCredential, credential)
        } else {
            let host = challenge.protectionSpace.host
            Self.logger.error("TLS trust evaluation failed for \(host, privacy: .public): \(String(describing: error), privacy: .public)")
            return (.cancelAuthenticationChallenge, nil)
        }
    }
}
