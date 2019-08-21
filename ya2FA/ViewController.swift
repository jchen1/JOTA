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

    let otp: OTP
    var timer: Timer?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        otp = try! OTP(url: "otpauth://totp/Twitter:@iambald?secret=7A3H374INDJGYDBY&issuer=Twitter")
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        timer = Timer(fireAt: Date(timeInterval: 1, since: Date()), interval: 1.0, target: self, selector: #selector(updateOTP), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.default)
    }
    
    required init?(coder: NSCoder) {
        otp = try! OTP(url: "otpauth://totp/Twitter:@iambald?secret=7A3H374INDJGYDBY&issuer=Twitter")

        super.init(coder: coder)
        timer = Timer(fireAt: Date(timeInterval: 0.1, since: Date()), interval: 1.0, target: self, selector: #selector(updateOTP), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.default)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateOTP()
    }
    
    @objc func updateOTP() {
        let now = Date()
        let timeLeft = 30 - (Int64(now.timeIntervalSince1970) % 30)
        let code = try! otp.generate(time: now)
        
        otpLabel.text = code
        timeLeftLabel.text = String(timeLeft)
        if (timeLeft <= 5) {
            otpLabel.textColor = UIColor.red
        } else {
            otpLabel.textColor = UIColor.black
        }
    }
}

