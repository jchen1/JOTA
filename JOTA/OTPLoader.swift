//
//  OTPLoader.swift
//  JOTA
//
//  Created by Jeff Chen on 8/21/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import Foundation
import KeychainAccess

class OTPLoader {
    static let service = "group.dev.jeffchen.jota"
    static let accessGroup = "45A594478C.dev.jeffchen.JOTA"
    
    public static func migrate(otps: [OTP]) {
        let keychain = Keychain(service: service, accessGroup: accessGroup).synchronizable(true)
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: otps, requiringSecureCoding: false)
            try keychain.set(data, key: "otps")
        } catch let error {
            fatalError("error migrating data: \(error)")
        }
    }
    
    public static func hasMigrated() -> Bool {
        let userDefaults = UserDefaults.init(suiteName: service)
        let hasOld = userDefaults?.object(forKey: "otps") != nil

        let keychain = Keychain(service: service, accessGroup: accessGroup).synchronizable(true)
        return !hasOld || (try! keychain.getData("otps") != nil)
    }
    
    public static func loadOTPs() -> [OTP] {
        if hasMigrated() {
            do {
                let keychain = Keychain(service: service, accessGroup: accessGroup).synchronizable(true)
                if let data = try keychain.getData("otps") {
                                
                    NSKeyedUnarchiver.setClass(OTP.self, forClassName: "jota.OTP")
                    NSKeyedUnarchiver.setClass(OTP.self, forClassName: "JOTA.OTP")
                    NSKeyedUnarchiver.setClass(OTP.self, forClassName: "JOTA_macOS.OTP")
                    NSKeyedUnarchiver.setClass(OTP.self, forClassName: "OTP")
                    guard let otps = NSKeyedUnarchiver.unarchiveObject(with: data as Data) as? [OTP] else {
                        fatalError("corrupt data!")
                    }
                        
                    return otps
                } else {
                    return []
                }

            } catch let error {
                fatalError("corrupt data: \(error)")
            }

        } else {
            let userDefaults = UserDefaults.init(suiteName: "group.dev.jeffchen.jota")
            if let otpData = userDefaults?.object(forKey: "otps") as? NSData {
                NSKeyedUnarchiver.setClass(OTP.self, forClassName: "jota.OTP")
                NSKeyedUnarchiver.setClass(OTP.self, forClassName: "JOTA.OTP")
                NSKeyedUnarchiver.setClass(OTP.self, forClassName: "JOTA_macOS.OTP")
                NSKeyedUnarchiver.setClass(OTP.self, forClassName: "OTP")
                guard let otps = NSKeyedUnarchiver.unarchiveObject(with: otpData as Data) as? [OTP] else {
                    fatalError("corrupt data!")
                }
                
                migrate(otps: otps)
                
                return otps
            }
            
            return [OTP]()
        }
    }
    
    public static func saveOTPs(otps: [OTP]) throws {
        return migrate(otps: otps)
    }
}
