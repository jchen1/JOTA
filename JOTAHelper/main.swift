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
    /// Code for the following period, so callers can roll over without re-authenticating.
    let nextCode: String?
    let period: Int?
    let secondsLeft: Int?
    let suggested: Bool
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

func requireUnlock() {
    var finished = false
    var unlocked = false
    AutoFillLock.authenticate(reason: "show your verification codes") { success in
        unlocked = success
        finished = true
    }
    while !finished {
        RunLoop.main.run(mode: .default, before: .distantFuture)
    }
    if !unlocked {
        fail("locked", code: 3)
    }
}

func list(arguments: [String]) {
    requireUnlock()
    let otps = OTPLoader.loadOTPs()
    let suggested = AutoFillIdentities.suggestions(for: hosts(forURL: option("--url", in: arguments)), in: otps)
    let suggestedIDs = Set(suggested.map(\.autofillRecordID))
    let others = otps
        .filter { !suggestedIDs.contains($0.autofillRecordID) }
        .sorted { ($0.label ?? "").lowercased() < ($1.label ?? "").lowercased() }

    let now = Int(Date().timeIntervalSince1970)
    let entries = (suggested + others).compactMap { otp -> CodeEntry? in
        guard let code = try? otp.generate() else { return nil }
        let period = otp.timeInterval
        return CodeEntry(
            id: otp.autofillRecordID,
            label: otp.label ?? "",
            user: otp.user ?? "",
            code: code,
            nextCode: period.flatMap { try? otp.generate(time: Date(timeIntervalSince1970: TimeInterval(now - now % $0 + $0))) },
            period: period,
            secondsLeft: period.map { $0 - now % $0 },
            suggested: suggestedIDs.contains(otp.autofillRecordID)
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
