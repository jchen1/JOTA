//
//  OTPLoader.swift
//  JOTA
//
//  Created by Jeff Chen on 8/21/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import Foundation

class OTPLoader {
    public static func loadOTPs() -> [OTP] {
        let userDefaults = UserDefaults.init(suiteName: "group.dev.jeffchen.jota")
        if let otpData = userDefaults?.object(forKey: "otps") as? NSData {
            NSKeyedUnarchiver.setClass(OTP.self, forClassName: "jota.OTP")
            NSKeyedUnarchiver.setClass(OTP.self, forClassName: "OTP")
            guard let otps = NSKeyedUnarchiver.unarchiveObject(with: otpData as Data) as? [OTP] else {
                fatalError("corrupt data!")
            }
            
            return otps
        }
        
        return [OTP]()
    }
    
    public static func saveOTPs(otps: [OTP]) throws {
        let userDefaults = UserDefaults.init(suiteName: "group.dev.jeffchen.jota")
        NSKeyedArchiver.setClassName("OTP", for: OTP.self)
        let data = try NSKeyedArchiver.archivedData(withRootObject: otps, requiringSecureCoding: false)
        userDefaults!.set(data, forKey: "otps")
    }
}
