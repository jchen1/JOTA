//
//  ViewController.swift
//  ya2FA
//
//  Created by Jeff Chen on 8/21/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var otpLabel: UILabel!
    @IBOutlet weak var timeLeftLabel: UILabel!

    var otps: [OTP] = []
//    let otp: OTP
    var timer: Timer?
    let userDefaults = UserDefaults(suiteName: "group.dev.jeffchen.ya2fa")

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
//        otp = try! OTP(url: "otpauth://totp/Twitter:@iambald?secret=7A3H374INDJGYDBY&issuer=Twitter")
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setup()
    }
    
    required init?(coder: NSCoder) {
//        otp = try! OTP(url: "otpauth://totp/Twitter:@iambald?secret=7A3H374INDJGYDBY&issuer=Twitter")
//
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        self.otps = OTPLoader.loadOTPs()
        
        timer = Timer(fireAt: Date(timeInterval: 0.1, since: Date()), interval: 1.0, target: self, selector: #selector(updateOTPs), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.default)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateOTPs()
    }
    
    @objc func updateOTPs() {
        let now = Date()
        let timeLeft = 30 - (Int64(now.timeIntervalSince1970) % 30)
        for (i, otp) in self.otps.enumerated() {
            let code = try! otp.generate(time: now)
    
            if (i == 0) {
                otpLabel.text = code
                timeLeftLabel.text = String(timeLeft)
                if (timeLeft <= 5) {
                    otpLabel.textColor = UIColor.red
                } else {
                    otpLabel.textColor = UIColor.black
                }
            }
        }
        // this happens every second and probably doesn't need to
        try! OTPLoader.saveOTPs(otps: self.otps)
    }

}

