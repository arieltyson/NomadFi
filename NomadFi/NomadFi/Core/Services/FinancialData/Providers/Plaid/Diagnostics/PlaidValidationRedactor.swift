// PlaidValidationRedactor.swift
// NomadFi
//
// Pure redaction helpers for the DEBUG-only Plaid validation
// recorder. The recorder never accepts free-form strings from
// callers into the exported artifact; every detail goes through one
// of these narrow helpers first so the export remains safe to hand
// back to Claude (or any other analyst) without leaking:
//
// - Plaid `public_token` / `access_token` / `link_token`
// - Plaid `client_id` / `secret`
// - The full local broker URL (would leak the developer's LAN IP)
// - The shared broker secret
// - Full Plaid item handles (kept only in masked form)
//
// Rules are deterministic and covered by tests.

#if DEBUG

import Foundation

enum PlaidValidationRedactor {

    // MARK: - Item handle

    /// Masks a Plaid item handle so the export keeps the `itm_`
    /// prefix (useful for identifying the token shape) and the last
    /// four characters (useful for distinguishing sessions across
    /// reruns) while hiding the entropy in the middle.
    ///
    /// - Handles shorter than eight characters collapse to all stars
    ///   so we never leak a small handle's full body.
    static func maskedItemHandle(_ raw: String?) -> String? {
        guard let raw = raw?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }

        if raw.count < 8 {
            return String(repeating: "*", count: max(raw.count, 1))
        }
        let prefix = raw.prefix(4)
        let suffix = raw.suffix(4)
        return "\(prefix)****\(suffix)"
    }

    // MARK: - Broker URL presence

    /// Reduces a broker URL to a presence flag. We deliberately do
    /// **not** export hostnames or IP addresses: a developer's LAN
    /// IP is metadata about their home network, not validation
    /// evidence.
    static func brokerURLPresence(from url: URL?) -> String {
        url == nil ? "missing" : "configured"
    }

    // MARK: - Error messages

    /// Collapses an error's `localizedDescription` into a short,
    /// redaction-safe label. Specifically strips things that look
    /// like URLs, host names, IP addresses, and long hex strings.
    ///
    /// Empty input returns `"unknown"` so the exported artifact
    /// never has blank error reasons.
    static func redactedError(_ raw: String?) -> String {
        guard var message = raw?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !message.isEmpty else {
            return "unknown"
        }
        let patterns: [String] = [
            #"https?://[^\s]+"#,                // URLs
            #"\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b"#, // IPv4[:port]
            #"\b[A-Fa-f0-9]{16,}\b"#,           // long hex tokens
        ]
        for pattern in patterns {
            guard let regex = try? Regex(pattern) else { continue }
            message = message.replacing(regex, with: "[redacted]")
        }
        let collapsedSpaces = message
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsedSpaces.isEmpty ? "unknown" : collapsedSpaces
    }

    // MARK: - Institution names

    /// Institution display names like "Royal Bank of Canada" are
    /// the most load-bearing piece of evidence for criterion 5
    /// (target Canadian FI coverage). We accept them in the export
    /// but explicitly pass through `include` so the UI can surface
    /// the choice and the developer controls whether a specific run
    /// reveals the FI.
    static func institutionName(_ raw: String?, include: Bool) -> String? {
        guard include else { return nil }
        guard let raw = raw?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !raw.isEmpty else {
            return nil
        }
        return raw
    }
}

#endif
