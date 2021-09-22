//
//  OTPTableViewController.swift
//  JOTA
//
//  Created by Jeff Chen on 8/22/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import UIKit
import Toaster

extension UIImage {
    func imageWithColor(color1: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        color1.setFill()

        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        context?.setBlendMode(CGBlendMode.normal)

        let rect = CGRect(origin: .zero, size: CGSize(width: self.size.width, height: self.size.height))
        context?.clip(to: rect, mask: self.cgImage!)
        context?.fill(rect)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
}

class OTPTableViewController: UITableViewController {
    let searchController = UISearchController(searchResultsController: nil)
    // MARK: - Table view data source
    var timer: Timer?

    var otps = [OTP]()
    var filteredOTPs = [OTP]()
    var isSearchBarEmpty: Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    var isFiltering: Bool {
      return searchController.isActive && !isSearchBarEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]

        tableView.tableFooterView = UIView()
        setup()
        
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search"

        // placeholder & icon color
        searchController.searchBar.searchTextField.textColor = UIColor.white
        
        searchController.searchBar.searchTextField.attributedPlaceholder = NSAttributedString(string: searchController.searchBar.searchTextField.placeholder ?? "", attributes: [NSAttributedString.Key.foregroundColor : UIColor.white])
        searchController.searchBar.searchTextField.leftView?.tintColor = UIColor.white
        
        if let clearButton = searchController.searchBar.searchTextField.value(forKey: "_clearButton") as? UIButton {
            if let img3 = clearButton.image(for: .highlighted) {
                clearButton.isHidden = false
                let tintedClearImage = img3.imageWithColor(color1: UIColor.white)
                clearButton.setImage(tintedClearImage, for: .normal)
                clearButton.setImage(tintedClearImage, for: .highlighted)
            }else{
               clearButton.isHidden = true
            }
        }
        
        // cancel text
        let appearance = UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
        appearance.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: .normal)
        
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (isFiltering) {
            return filteredOTPs.count
        }
        return otps.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "OTPTableViewCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? OTPTableViewCell else {
            fatalError("not a OTPTableViewCell :(")
        }
        
        let otp = isFiltering ? filteredOTPs[indexPath.row] : otps[indexPath.row]
        
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
            let alert = UIAlertController(title: "Delete OTP (\(otp.label ?? otp.description))", message: "Are you sure? Be sure to disable 2FA before removing.", preferredStyle: .alert)
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
        let otp = isFiltering ? filteredOTPs[indexPath.row] : otps[indexPath.row]
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
    
    func filterContentForSearchText(_ searchText: String) {
        filteredOTPs = otps.filter { otp in
            (otp.label?.lowercased().contains(searchText.lowercased()) ?? false) ||
            (otp.user?.lowercased().contains(searchText.lowercased()) ?? false)
        }
      
      tableView.reloadData()
    }

}


extension OTPTableViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        // probably we want this on a viewdidload for the searchbar but i'm lazy
        if searchBar.searchTextField.textColor != UIColor.white {
            searchBar.searchTextField.textColor = UIColor.white
        }

        filterContentForSearchText(searchBar.text!)
    }
}
