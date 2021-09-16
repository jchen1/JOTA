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
    
    private struct OTPSection {
        let index: Int
        let heading: String
        let otps: [OTP]
    }
    
    private var otpSections = [OTPSection]()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()

        // Get the item[s] we're handling from the extension context.
        for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
            for provider in item.attachments! {
                if provider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                    provider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil, completionHandler: { (item, error) in
                        guard let dictionary = item as? NSDictionary else { return }
                        OperationQueue.main.addOperation {
                            if let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
                                // https://twitter.com/account/login_verification?challenge_type=Totp
                                let host = results.value(forKey: "host") as! String?
                                self.otpSections = self.makeSections(otps: OTPLoader.loadOTPs(), host: host)
                            }
                        }
                    })
                }
            }
        }
        
        timer = Timer(fireAt: Date(timeInterval: 0.1, since: Date()), interval: 0.1, target: self, selector: #selector(updateOTPs), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.default)
    }
    
    private func canonicalize(str: String?) -> String {
        let characterSet = CharacterSet(charactersIn: "qwertyuiopasdfghjklzxcvbnm")
        return str?.lowercased().components(separatedBy: characterSet.inverted).joined() ?? ""
    }
    
    private func makeSections(otps: [OTP], host: String?) -> [OTPSection] {
        let host = canonicalize(str: host) // todo remove special chars...
        
        var sections = [OTPSection]()
        let suggestedOTPs = otps.filter({ (otp) in
            return host.contains(canonicalize(str: otp.label))
        })
        
        if suggestedOTPs.count > 0 {
            sections += [OTPSection(index: sections.count, heading: "Suggestions", otps: suggestedOTPs)]
        }
        sections += [OTPSection(index: sections.count, heading: "All Tokens", otps: otps)]
        
        return sections
    }
    
    @objc private func updateOTPs() {
        if !self.tableView.isEditing {
            self.tableView.reloadData()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return otpSections.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return otpSections[section].heading
    }
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return otpSections[section].otps.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "OTPTableViewCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? OTPTableViewCell else {
            fatalError("not a OTPTableViewCell :(")
        }
        
        let otp = otpSections[indexPath.section].otps[indexPath.row]
        
        cell.otpLabelLabel?.text = otp.label ?? ""
        // todo handle HOTP...
        cell.userLabel?.text = otp.user
        cell.otpCodeLabel?.text = try! otp.generate()
        
        let timeLeft = 30 - (Int64(Date().timeIntervalSince1970) % 30)
        if (timeLeft <= 5 && otp.type() == .TOTP) {
            cell.otpCodeLabel?.textColor = UIColor.red
        } else {
            if self.traitCollection.userInterfaceStyle == .dark {
                cell.otpCodeLabel?.textColor = UIColor.white
            } else {
                cell.otpCodeLabel?.textColor = UIColor.black
            }
        }
        cell.timeLeftLabel?.text = String(timeLeft)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let otp = otpSections[indexPath.section].otps[indexPath.row]
        let code = try? otp.generate()
        
        let item = NSExtensionItem()
        let jsDict = [ NSExtensionJavaScriptFinalizeArgumentKey : ["code": code ?? ""] ]
        
        item.attachments = [ NSItemProvider(item: jsDict as NSSecureCoding, typeIdentifier: kUTTypePropertyList as String)]
        self.extensionContext!.completeRequest(returningItems: [item], completionHandler: nil)
    }
    
    @IBAction func cancel() {
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

}
