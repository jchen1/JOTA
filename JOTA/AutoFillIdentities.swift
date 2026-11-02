//
//  AutoFillIdentities.swift
//  JOTA
//

import AuthenticationServices
import CryptoKit
import Foundation

extension OTP {
    /// Stable identifier for AutoFill that survives renaming and never reveals the secret.
    var autofillRecordID: String {
        SHA256.hash(data: secretData).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    var autofillDisplayName: String {
        let parts = [label, user].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.isEmpty ? "OTP" : parts.joined(separator: " · ")
    }
}

/// Remembers which OTP was filled on which site, and registers those pairs with
/// the system so the keyboard can suggest the right code directly next time.
enum AutoFillIdentities {
    private static let learnedHostsKey = "autofillLearnedHosts"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: OTPLoader.service)
    }

    /// Normalized host → `autofillRecordID`.
    static var learnedHosts: [String: String] {
        defaults?.dictionary(forKey: learnedHostsKey) as? [String: String] ?? [:]
    }

    static func otps(learnedFor host: String, in otps: [OTP]) -> [OTP] {
        guard let recordID = learnedHosts[OTPMatcher.normalizedHost(host)] else { return [] }
        return otps.filter { $0.autofillRecordID == recordID }
    }

    static func remember(_ otp: OTP, forHosts hosts: [String], allOTPs: [OTP]) {
        var learned = learnedHosts
        for host in hosts.map(OTPMatcher.normalizedHost) where !host.isEmpty {
            learned[host] = otp.autofillRecordID
        }
        defaults?.set(learned, forKey: learnedHostsKey)
        sync(otps: allOTPs)
    }

    /// Likely domains for an OTP based on its label: "Facebook" → facebook.com,
    /// "Google Workspace" → google.com and googleworkspace.com. Wrong guesses are harmless
    /// because they simply never match a page.
    static func guessedDomains(for otp: OTP) -> Set<String> {
        guard let label = otp.label?.trimmingCharacters(in: .whitespaces).lowercased(), !label.isEmpty else {
            return []
        }
        if label.contains("."), !label.contains(" ") {
            return [OTPMatcher.normalizedHost(label)]
        }

        var guesses = Set<String>()
        let full = OTPMatcher.canonicalize(label)
        if full.count >= 3 {
            guesses.insert(full + ".com")
        }
        if let firstWord = label.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).first.map(String.init),
           firstWord.count >= 3 {
            guesses.insert(firstWord + ".com")
        }
        return guesses
    }

    /// Drops mappings for deleted OTPs and registers learned and guessed sites with the system.
    static func sync(otps: [OTP], completion: (() -> Void)? = nil) {
        let otpsByID = Dictionary(otps.map { ($0.autofillRecordID, $0) }, uniquingKeysWith: { first, _ in first })
        let learned = learnedHosts.filter { otpsByID[$0.value] != nil }
        defaults?.set(learned, forKey: learnedHostsKey)

        var pairs = Set<HostRecord>()
        for (host, recordID) in learned {
            pairs.insert(HostRecord(host: host, recordID: recordID))
        }
        for otp in otps {
            for host in guessedDomains(for: otp) {
                pairs.insert(HostRecord(host: host, recordID: otp.autofillRecordID))
            }
        }

        let identities: [ASCredentialIdentity] = pairs.compactMap { pair in
            guard let otp = otpsByID[pair.recordID] else { return nil }
            return ASOneTimeCodeCredentialIdentity(
                serviceIdentifier: ASCredentialServiceIdentifier(identifier: pair.host, type: .domain),
                label: otp.autofillDisplayName,
                recordIdentifier: pair.recordID
            )
        }

        let store = ASCredentialIdentityStore.shared
        store.getState { state in
            guard state.isEnabled else {
                completion?()
                return
            }
            store.replaceCredentialIdentities(identities) { _, error in
                if let error = error {
                    NSLog("JOTA: failed to update AutoFill identities: \(error)")
                }
                completion?()
            }
        }
    }

    private struct HostRecord: Hashable {
        let host: String
        let recordID: String
    }
}
