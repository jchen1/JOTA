//
//  main.swift
//  JOTAHelper
//
//  Command-line access to JOTA codes for launchers like Raycast. Lives inside
//  JOTA-macOS.app so it is signed with JOTA's keychain access group.
//
//  Usage:
//    JOTAHelper list [--url <url>]        JSON array of codes, site matches first
//

import Foundation

struct CodeEntry: Encodable {
    let id: String
    let label: String
    let user: String
    let code: String
    /// Code for the following period, so callers can roll over without asking again.
    let nextCode: String?
    let period: Int?
    /// Unix time when `code` expires; `nextCode` is valid for one period after that.
    let expiresAt: Int?
    /// Matches the site loosely (label match); show it first.
    let suggested: Bool
    /// Matches the site strongly enough to paste without the user choosing.
    let confident: Bool
}

struct ErrorOutput: Encodable {
    let error: String
}

func printJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    if let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) {
        print(text)
    }
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    printJSON(ErrorOutput(error: message))
    exit(code)
}

func option(_ name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

func hosts(forURL url: String?) -> [String] {
    guard let url = url, !url.isEmpty else { return [] }
    let host = OTPMatcher.normalizedHost(url)
    return host.isEmpty ? [] : [host]
}

func list(arguments: [String]) {
    let hostList = hosts(forURL: option("--url", in: arguments))
    let otps = OTPLoader.loadOTPs()
    let suggested = AutoFillIdentities.suggestions(for: hostList, in: otps)
    let suggestedIDs = Set(suggested.map(\.autofillRecordID))
    let others = otps
        .filter { !suggestedIDs.contains($0.autofillRecordID) }
        .sorted { ($0.label ?? "").lowercased() < ($1.label ?? "").lowercased() }

    // One timestamp for every code so expiry times line up with what was generated.
    let now = Int(Date().timeIntervalSince1970)
    let entries = (suggested + others).compactMap { otp -> CodeEntry? in
        let period = otp.timeInterval
        let expiresAt = period.map { now - now % $0 + $0 }
        let code = period == nil
            ? try? otp.generate()
            : try? otp.generate(time: Date(timeIntervalSince1970: TimeInterval(now)))
        guard let code = code else { return nil }
        return CodeEntry(
            id: otp.autofillRecordID,
            label: otp.label ?? "",
            user: otp.user ?? "",
            code: code,
            nextCode: expiresAt.flatMap { try? otp.generate(time: Date(timeIntervalSince1970: TimeInterval($0))) },
            period: period,
            expiresAt: expiresAt,
            suggested: suggestedIDs.contains(otp.autofillRecordID),
            confident: suggestedIDs.contains(otp.autofillRecordID) && AutoFillIdentities.isConfidentMatch(otp, hosts: hostList)
        )
    }
    printJSON(entries)
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "list":
    list(arguments: arguments)
default:
    fail("usage: JOTAHelper list [--url <url>]", code: 64)
}
