//
//  OTPMatcher.swift
//  JOTA
//

import Foundation

/// Picks which OTPs are likely meant for a given website host by comparing the
/// host against each OTP's label (issuer).
enum OTPMatcher {
    /// Host components that say nothing about which service a page belongs to.
    private static let genericHostComponents: Set<String> = [
        "www", "login", "signin", "auth", "account", "accounts", "secure", "sso", "id", "app", "my",
        "com", "net", "org", "io", "co", "dev", "uk", "us", "edu", "gov",
    ]

    private static let minimumLabelLength = 3

    static func canonicalize(_ str: String?) -> String {
        let letters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
        return str?.lowercased().components(separatedBy: letters.inverted).joined() ?? ""
    }

    /// Normalizes a host or URL string to a lowercased host without a leading `www.`.
    static func normalizedHost(_ hostOrURL: String) -> String {
        let trimmed = hostOrURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let host: String
        if trimmed.contains("://"), let parsed = URL(string: trimmed)?.host {
            host = parsed
        } else {
            host = trimmed.split(separator: "/").first.map(String.init) ?? trimmed
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func matches(_ otp: OTP, host: String) -> Bool {
        let label = canonicalize(otp.label)
        guard label.count >= minimumLabelLength else { return false }

        let host = normalizedHost(host)
        if canonicalize(host).contains(label) {
            return true
        }

        // "Google Workspace" should still match accounts.google.com.
        return host.split(separator: ".")
            .map { canonicalize(String($0)) }
            .contains { component in
                component.count >= 4 && !genericHostComponents.contains(component) && label.hasPrefix(component)
            }
    }

    static func suggestions(from otps: [OTP], host: String?) -> [OTP] {
        guard let host = host, !host.isEmpty else { return [] }
        return otps.filter { matches($0, host: host) }
    }
}
