//
//  OTPTableViewController.swift
//  JOTA
//
//  Created by Jeff Chen on 8/22/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import UIKit
import Toaster

class OTPTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        setup()
    }

    // MARK: - Table view data source
    var otps = [OTP]()
    var timer: Timer?

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
        if (timeLeft <= 5 && otp.type() == .TOTP) {
            cell.otpCodeLabel?.textColor = UIColor.red
        } else {
            cell.otpCodeLabel?.textColor = UIColor.black
        }
        
        cell.timeLeftLabel?.text = {
            if (otp.type() == .TOTP) {
                return String(timeLeft)
            } else {
                return ""
            }
        }()
        
        return cell
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let otp = self.otps[indexPath.row]
            // Delete the row from the data source
            let alert = UIAlertController(title: "Delete OTP (\(otp.label ?? otp.description ?? ""))", message: "Are you sure? Be sure to disable 2FA before removing.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
                self.otps.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
                try! OTPLoader.saveOTPs(otps: self.otps)
            }))
            
            self.present(alert, animated: true)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let otp = otps[indexPath.row]
        guard let code = try? otp.generate() else { return }
        
        UIPasteboard.general.string = code
        Toast(text: "Copied to clipboard").show()
    }
    
    private func setup() {
        self.otps = OTPLoader.loadOTPs().sorted(by: { (a, b) -> Bool in
            a.label?.lowercased() ?? "" < b.label?.lowercased() ?? ""
        })
        
        timer = Timer(fireAt: Date(timeInterval: 0.1, since: Date()), interval: 0.1, target: self, selector: #selector(updateOTPs), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.default)
    }
    
    @objc private func updateOTPs() {
        if !self.tableView.isEditing {
            self.tableView.reloadData()
        }
        
        // this happens every second and probably doesn't need to
        try! OTPLoader.saveOTPs(otps: self.otps)
    }
    
    @IBAction func unwindToOTPList(sender: UIStoryboardSegue) {
        if let source = sender.source as? ScannerViewController, let otp = source.otp {
            let index = self.otps.firstIndex { (tableOTP) -> Bool in
                tableOTP.label?.lowercased() ?? "" >= otp.label?.lowercased() ?? ""
            } ?? self.otps.count
            let newIndexPath = IndexPath(row: index, section: 0)
            otps.insert(otp, at: index)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        }
    }

}
