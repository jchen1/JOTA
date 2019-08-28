//
//  OTP.swift
//  JOTA
//
//  Created by Jeff Chen on 8/21/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import Foundation
import SwiftOTP

public class OTP: NSObject,NSCoding {
    public enum OTPType: Int32 {
        case TOTP = 0
        case HOTP = 1
    }
    
    public enum OTPError: Error {
        case unableToCreateOTP
        case invalidURL
        case invalidOrMissingScheme
        case invalidOrMissingType
        case invalidOrMissingSecret
        case unimplemented
        case unableToGenerateCode
        case unsupportedAlgorithm
        case wrongOTPType
    }
    
    public enum OTPContainer {
        case TOTP(TOTP)
        case HOTP(HOTP, UInt64)
    }
    
    private enum Keys: String {
        case type = "Type"
        case secret = "Secret"
        case user = "User"
        case label = "Label"
        case digits = "Digits"
        case timeInterval = "Time Interval"
        case counter = "Counter"
        case algorithm = "Algorithm"
    }
    
    public let label: String?
    public let user: String?
    public var otpContainer: Optional<OTPContainer> = .none
    
    public init(type: OTPType, secret: Data, user: String?, label: String?, digits: Int?, timeInterval: Int?, counter: UInt64?, algorithm: OTPAlgorithm?) throws {
        self.user = user
        self.label = label

        let digits = digits ?? 6
        let timeInterval = timeInterval ?? 30
        let algorithm = algorithm ?? OTPAlgorithm.sha1
        
        switch type {
        case .HOTP:
            guard let hotp = HOTP(secret: secret, digits: digits, algorithm: algorithm) else {
                throw OTPError.unableToCreateOTP
            }
            guard let counter: UInt64 = counter else {
                throw OTPError.unableToCreateOTP
            }
            otpContainer = .HOTP(hotp, counter)
            break
        case .TOTP:
            guard let totp = TOTP(secret: secret, digits: digits, timeInterval: timeInterval, algorithm: algorithm) else {
                throw OTPError.unableToCreateOTP
            }
            otpContainer = .TOTP(totp)
            break
        }
    }
    
    public convenience init(type: OTPType, secret: Data, user: String?, label: String?, counter: UInt64?) throws {
        try self.init(type: type, secret: secret, user: user, label: label, digits: nil, timeInterval: nil, counter: counter, algorithm: nil)
    }
    
    public convenience init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw OTPError.invalidURL
        }
                
        if components.scheme != "otpauth" {
            throw OTPError.invalidOrMissingScheme
        }
        
        let otpType = try { () -> OTPType in
            switch components.host {
            case "totp": return OTPType.TOTP
            case "hotp": return OTPType.HOTP
            default: throw OTPError.invalidOrMissingType
            }
        }()
        
        let paths = components.path.split(separator: ":")
        // remove leading '/'
        let label: String? = paths.count > 0 ? String(paths[0].suffix(from: paths[0].index(paths[0].startIndex, offsetBy: 1))) : nil;
        let user: String? = paths.count > 1 ? String(paths[1]) : nil;
        
        var queryDict = [String:String]()
        if let queryItems = components.queryItems {
            for item in queryItems {
                queryDict[item.name] = item.value!
            }
        }
                
        guard let secret = queryDict["secret"]?.base32DecodedData else {
            throw OTPError.invalidOrMissingSecret
        }
        let digits = Int(queryDict["digits"] ?? "")
        let timeInterval = Int(queryDict["interval"] ?? "")
        let counter = UInt64(queryDict["counter"] ?? "0")
        let algorithm: OTPAlgorithm = try {
            switch queryDict["algorithm"] ?? "sha1" {
            case "sha1": return OTPAlgorithm.sha1
            case "sha256": return OTPAlgorithm.sha256
            case "sha512": return OTPAlgorithm.sha512
            default: throw OTPError.unsupportedAlgorithm
            }
        }()
        
        try self.init(type: otpType, secret: secret, user: user, label: label, digits: digits, timeInterval: timeInterval, counter: counter, algorithm: algorithm)
    }
    
    public convenience init(url: String) throws {
        guard let url = URL(string: url) else {
            throw OTPError.invalidURL
        }
        try self.init(url: url)
    }
    
    required public convenience init?(coder: NSCoder) {
        let type = OTPType(rawValue: coder.decodeInt32(forKey: Keys.type.rawValue))!
        let b32Secret = coder.decodeObject(forKey: Keys.secret.rawValue) as! String
        guard let secret = b32Secret.base32DecodedData else { return nil }
        
        let user = coder.decodeObject(forKey: Keys.user.rawValue) as! String
        let label = coder.decodeObject(forKey: Keys.label.rawValue) as! String
        let digits = coder.decodeInteger(forKey: Keys.digits.rawValue)
        let timeInterval: Int? = {
            switch type {
            case .TOTP:
                return coder.decodeInteger(forKey: Keys.timeInterval.rawValue)
            case .HOTP:
                return nil
            }
        }()
        let counter: UInt64? = {
            switch type {
            case .TOTP:
                return nil
            case .HOTP:
                return coder.decodeObject(forKey: Keys.counter.rawValue) as? UInt64
            }
        }()
        let algorithm = OTPAlgorithm(rawValue: coder.decodeInt32(forKey: Keys.algorithm.rawValue))!
        
        do {
            try self.init(type: type, secret: secret, user: user, label: label, digits: digits, timeInterval: timeInterval, counter: counter, algorithm: algorithm)
        } catch {
            return nil
        }
    }
    
    public func encode(with coder: NSCoder) {
        switch otpContainer! {
        case .HOTP(let hotp, let counter):
            coder.encode(OTPType.HOTP.rawValue, forKey: Keys.type.rawValue)
            coder.encode(hotp.secret.base32EncodedString, forKey: Keys.secret.rawValue)
            coder.encode(hotp.digits, forKey: Keys.digits.rawValue)
            coder.encode(counter, forKey: Keys.counter.rawValue)
            coder.encode(hotp.algorithm.rawValue, forKey: Keys.algorithm.rawValue)
            break
        case .TOTP(let totp):
            coder.encode(OTPType.TOTP.rawValue, forKey: Keys.type.rawValue)
            coder.encode(totp.secret.base32EncodedString, forKey: Keys.secret.rawValue)
            coder.encode(totp.digits, forKey: Keys.digits.rawValue)
            coder.encode(totp.timeInterval, forKey: Keys.timeInterval.rawValue)
            coder.encode(totp.algorithm.rawValue, forKey: Keys.algorithm.rawValue)
            break
        }
        
        coder.encode(user ?? "", forKey: Keys.user.rawValue)
        coder.encode(label ?? "", forKey: Keys.label.rawValue)
    }
    
    public func generate(time: Date) throws -> String {
        switch otpContainer! {
        case .HOTP:
            throw OTPError.wrongOTPType
        case .TOTP(let totp):
            if let code = totp.generate(time: time) {
                return code
            }
            throw OTPError.unableToGenerateCode
        }
    }
    
    public func generate() throws -> String {
        switch otpContainer! {
        case .HOTP(let hotp, let counter):
            guard let code = hotp.generate(counter: counter) else {
                throw OTPError.unableToGenerateCode
            }
            return code
        case .TOTP:
            return try generate(time: Date())
        }
    }
    
    public func confirmGeneration() {
        switch otpContainer! {
        case .HOTP(let hotp, let counter):
            otpContainer = .HOTP(hotp, counter + 1)
            break
        case .TOTP:
            break
        }
    }
    
    public func type() -> OTPType {
        switch otpContainer! {
        case .HOTP:
            return OTPType.HOTP
        case .TOTP:
            return OTPType.TOTP
        }
    }
}
