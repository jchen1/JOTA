//
//  OTPTableViewController.swift
//  ya2FA
//
//  Created by Jeff Chen on 8/22/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import UIKit

class OTPTableViewController: UITableViewController {
//    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
//        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
//        setup()
//    }
//
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        setup()
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
//         self.navigationItem.rightBarButtonItem = self.editButtonItem
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
        if (timeLeft <= 5) {
            cell.otpCodeLabel?.textColor = UIColor.red
        } else {
            cell.otpCodeLabel?.textColor = UIColor.black
        }
        cell.timeLeftLabel?.text = String(timeLeft)
        
        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            otps.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            try! OTPLoader.saveOTPs(otps: otps)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
 

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        
    }
    */
    
    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    private func setup() {
        self.otps = OTPLoader.loadOTPs()
        
        timer = Timer(fireAt: Date(timeInterval: 0.1, since: Date()), interval: 1.0, target: self, selector: #selector(updateOTPs), userInfo: nil, repeats: true)
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
            let newIndexPath = IndexPath(row: otps.count, section: 0)
            otps.append(otp)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        }
    }

}
