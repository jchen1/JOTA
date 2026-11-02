//
//  AutoFillLock.swift
//  JOTA
//

import Foundation
import KeychainAccess
import LocalAuthentication

/// Gates AutoFill behind Face ID / Touch ID / passcode, with an optional grace
/// window during which codes are filled without asking again.
enum AutoFillLock {
    enum Timeout: Int, CaseIterable {
        case always = 0
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case oneHour = 3600

        var title: String {
            switch self {
            case .always: return "Every time"
            case .oneMinute: return "After 1 minute"
            case .fiveMinutes: return "After 5 minutes"
            case .fifteenMinutes: return "After 15 minutes"
            case .oneHour: return "After 1 hour"
            }
        }
    }

    private static let timeoutDefaultsKey = "autofillAuthTimeout"
    private static let lastAuthKey = "autofillLastAuth"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: OTPLoader.service)
    }

    /// Device-only, never synced to iCloud: unlocking on one device must not unlock another.
    private static var keychain: Keychain {
        Keychain(service: OTPLoader.service, accessGroup: OTPLoader.accessGroup)
            .synchronizable(false)
            .accessibility(.whenUnlockedThisDeviceOnly)
    }

    static var timeout: Timeout {
        get {
            Timeout(rawValue: defaults?.integer(forKey: timeoutDefaultsKey) ?? 0) ?? .always
        }
        set {
            defaults?.set(newValue.rawValue, forKey: timeoutDefaultsKey)
            if newValue == .always {
                lock()
            }
        }
    }

    static var isUnlocked: Bool {
        guard timeout != .always,
              let stored = try? keychain.getString(lastAuthKey),
              let lastAuth = TimeInterval(stored) else {
            return false
        }
        let elapsed = Date().timeIntervalSince1970 - lastAuth
        // A negative elapsed time means the clock moved backwards; don't trust it.
        return elapsed >= 0 && elapsed < TimeInterval(timeout.rawValue)
    }

    static func lock() {
        try? keychain.remove(lastAuthKey)
    }

    /// Calls `completion(true)` immediately while unlocked (if `allowGracePeriod`),
    /// otherwise prompts. `completion` is always called on the main queue.
    static func authenticate(reason: String, allowGracePeriod: Bool = true, completion: @escaping (Bool) -> Void) {
        if allowGracePeriod && isUnlocked {
            DispatchQueue.main.async { completion(true) }
            return
        }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set: there is nothing to authenticate against.
            DispatchQueue.main.async { completion(true) }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            if success && allowGracePeriod {
                try? keychain.set(String(Date().timeIntervalSince1970), key: lastAuthKey)
            }
            DispatchQueue.main.async { completion(success) }
        }
    }
}
