//
//  OTPBackup.swift
//  JOTA
//

import Foundation
import SwiftOTP

extension OTP {
    /// Standard `otpauth://` URI, importable by JOTA and most other authenticators.
    var otpauthURL: URL? {
        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = type() == .TOTP ? "totp" : "hotp"
        components.path = "/" + (label ?? "") + (user.map { ":" + $0 } ?? "")

        var query = [URLQueryItem(name: "secret", value: secretBase32)]
        if let label = label, !label.isEmpty {
            query.append(URLQueryItem(name: "issuer", value: label))
        }
        query.append(URLQueryItem(name: "algorithm", value: algorithmName))
        query.append(URLQueryItem(name: "digits", value: String(digits)))
        if let period = timeInterval {
            query.append(URLQueryItem(name: "period", value: String(period)))
        }
        if let counter = counter {
            query.append(URLQueryItem(name: "counter", value: String(counter)))
        }
        components.queryItems = query
        return components.url
    }

    fileprivate var algorithmName: String {
        switch algorithm {
        case .sha1: return "SHA1"
        case .sha256: return "SHA256"
        case .sha512: return "SHA512"
        }
    }
}

enum OTPBackup {
    enum BackupError: LocalizedError {
        case unexportable(String)
        case roundTripMismatch

        var errorDescription: String? {
            switch self {
            case .unexportable(let name): return "Couldn't export \(name)"
            case .roundTripMismatch: return "Backup didn't match the stored codes"
            }
        }
    }

    struct ImportResult {
        let merged: [OTP]
        let added: Int
        let duplicates: Int
        let invalidLines: Int
    }

    /// One `otpauth://` URI per line. Re-parses the output and throws unless every
    /// OTP survives the round trip unchanged.
    static func export(_ otps: [OTP]) throws -> String {
        let lines = try otps.map { otp -> String in
            guard let url = otp.otpauthURL?.absoluteString else {
                throw BackupError.unexportable(otp.autofillDisplayName)
            }
            return url
        }
        let text = lines.joined(separator: "\n") + "\n"

        let reparsed = parse(text)
        guard reparsed.invalidLines == 0,
              reparsed.otps.map(fingerprint) == otps.map(fingerprint) else {
            throw BackupError.roundTripMismatch
        }
        return text
    }

    static func parse(_ text: String) -> (otps: [OTP], invalidLines: Int) {
        var otps = [OTP]()
        var invalid = 0
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let otp = try? OTP(url: String(trimmed)) {
                otps.append(otp)
            } else {
                invalid += 1
            }
        }
        return (otps, invalid)
    }

    /// Adds OTPs from `text` to `existing`, skipping any whose secret is already present.
    static func merge(_ text: String, into existing: [OTP]) -> ImportResult {
        let parsed = parse(text)
        var seen = Set(existing.map(\.secretData))
        var merged = existing
        var duplicates = 0
        for otp in parsed.otps {
            if seen.insert(otp.secretData).inserted {
                merged.append(otp)
            } else {
                duplicates += 1
            }
        }
        return ImportResult(
            merged: merged,
            added: merged.count - existing.count,
            duplicates: duplicates,
            invalidLines: parsed.invalidLines
        )
    }

    private static func fingerprint(_ otp: OTP) -> String {
        [
            otp.type() == .TOTP ? "totp" : "hotp",
            otp.secretBase32,
            otp.label ?? "",
            otp.user ?? "",
            String(otp.digits),
            otp.timeInterval.map(String.init) ?? "",
            otp.counter.map(String.init) ?? "",
            otp.algorithmName,
        ].joined(separator: "|")
    }
}
