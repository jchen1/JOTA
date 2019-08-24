//
//  ActionViewController.swift
//  OTPAutoFill
//
//  Created by Jeff Chen on 8/21/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import UIKit
import MobileCoreServices

class ActionViewController: UITableViewController {
    var code: String?
    var timer: Timer?
    var otps = [OTP]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.otps = OTPLoader.loadOTPs()
        timer = Timer(fireAt: Date(timeInterval: 0.1, since: Date()), interval: 1.0, target: self, selector: #selector(updateOTPs), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.default)
//        // Get the item[s] we're handling from the extension context.
//        for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
//            for provider in item.attachments! {
//                if provider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
//                    provider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil, completionHandler: { (item, error) in
//                        guard let dictionary = item as? NSDictionary else { return }
//                        OperationQueue.main.addOperation {
//                            if let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
//                                // https://twitter.com/account/login_verification?challenge_type=Totp
//                                self.code = self.checkOTP(url: URL(string: results.object(forKey: "url")! as! String)!)
//                            }
//                        }
//                    })
//                }
//            }
//        }
    }
    
    @objc private func updateOTPs() {
        if !self.tableView.isEditing {
            self.tableView.reloadData()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return otps.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "OTPTableViewCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? OTPTableViewCell else {
            fatalError("not a OTPTableViewCell :(")
        }
        
        let otp = otps[indexPath.row]
        cell.otpLabelLabel?.text = otp.label ?? ""
        // todo handle HOTP...
        cell.userLabel?.text = otp.user
        cell.otpCodeLabel?.text = try! otp.generate()
        
        let timeLeft = 30 - (Int64(Date().timeIntervalSince1970) % 30)
        if (timeLeft <= 5) {
            cell.otpCodeLabel?.textColor = UIColor.red
        } else {
            cell.otpCodeLabel?.textColor = UIColor.black
        }
        cell.timeLeftLabel?.text = String(timeLeft)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let otp = otps[indexPath.row]
        let code = try? otp.generate()
        
        let item = NSExtensionItem()
        let jsDict = [ NSExtensionJavaScriptFinalizeArgumentKey :
            [
              "code": code ?? ""
            ]]
        
        item.attachments = [ NSItemProvider(item: jsDict as NSSecureCoding, typeIdentifier: kUTTypePropertyList as String)]
        self.extensionContext!.completeRequest(returningItems: [item], completionHandler: nil)
    }
    
    @IBAction func cancel() {
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

}
