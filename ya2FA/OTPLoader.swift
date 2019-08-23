//
//  OTPLoader.swift
//  ya2FA
//
//  Created by Jeff Chen on 8/21/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import Foundation

class OTPLoader {
    public static func loadOTPs() -> [OTP] {
        let userDefaults = UserDefaults.init(suiteName: "group.dev.jeffchen.ya2fa")
        var otps: [OTP] = []
        if let otpData = userDefaults?.object(forKey: "otps") as? NSData {
            NSKeyedUnarchiver.setClass(OTP.self, forClassName: "ya2FA.OTP")
            NSKeyedUnarchiver.setClass(OTP.self, forClassName: "OTP")
            guard let a = NSKeyedUnarchiver.unarchiveObject(with: otpData as Data) as? [OTP] else {
                fatalError("corrupt data!")
            }
            // hmm...
            otps = a
        }
        
        // lol yolo
        if (otps.count == 1) {
            otps.append(try! OTP(url: "otpauth://totp/Twitter:@iambald?secret=7A3H374INDJGYDBY&issuer=Twitter"))
            otps.append(try! OTP(url: "otpauth://totp/Rippling:Ladder%20Financial%20Inc.%20-%20hello%40jeff.yt?secret=XH57TYXTYVF007LQ&issuer=Rippling"))
        }
        
        return otps
    }
    
    public static func saveOTPs(otps: [OTP]) throws {
        let userDefaults = UserDefaults.init(suiteName: "group.dev.jeffchen.ya2fa")
        NSKeyedArchiver.setClassName("OTP", for: OTP.self)
        let data = try NSKeyedArchiver.archivedData(withRootObject: otps, requiringSecureCoding: false)
        userDefaults!.set(data, forKey: "otps")
    }
}
