//
//  OTPTableViewController.swift
//  JOTA
//
//  Created by Jeff Chen on 8/22/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import UIKit
import Toaster
import UniformTypeIdentifiers

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadOTPsFromStorage),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
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

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            menu: UIMenu(children: [
                UIAction(title: "AutoFill Face ID…", image: UIImage(systemName: "faceid")) { [weak self] _ in
                    self?.showAutoFillSettings()
                },
                UIAction(title: "Export Backup…", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                    self?.exportBackup()
                },
                UIAction(title: "Import Backup…", image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
                    self?.importBackup()
                },
            ])
        )
    }

    // MARK: - Backup

    private func exportBackup() {
        AutoFillLock.authenticate(reason: "Export all OTP secrets", allowGracePeriod: false) { [weak self] success in
            guard let self = self, success else { return }
            let otps = OTPLoader.loadOTPs()
            let text: String
            do {
                text = try OTPBackup.export(otps)
            } catch {
                Toast(text: error.localizedDescription).show()
                return
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("JOTA-backup-\(formatter.string(from: Date())).txt")
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                Toast(text: "Failed to write backup").show()
                return
            }

            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            share.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
            share.completionWithItemsHandler = { _, completed, _, _ in
                try? FileManager.default.removeItem(at: url)
                if completed {
                    Toast(text: "Exported \(otps.count) codes").show()
                }
            }
            self.present(share, animated: true)
        }
    }

    private func importBackup() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText, .text])
        picker.delegate = self
        present(picker, animated: true)
    }

    private func showAutoFillSettings() {
        let sheet = UIAlertController(
            title: "Require Face ID for AutoFill",
            message: "Enable JOTA under Settings › General › AutoFill & Passwords to fill codes from the keyboard.",
            preferredStyle: .actionSheet
        )
        for timeout in AutoFillLock.Timeout.allCases {
            let title = timeout == AutoFillLock.timeout ? "✓ \(timeout.title)" : timeout.title
            sheet.addAction(UIAlertAction(title: title, style: .default) { _ in
                AutoFillLock.timeout = timeout
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        present(sheet, animated: true)
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
            confirmDelete(at: indexPath)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }

    // MARK: - Swipe Actions

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] (_, _, completion) in
            self?.presentEditModal(for: indexPath)
            completion(true)
        }
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "pencil")

        return UISwipeActionsConfiguration(actions: [editAction])
    }

    // MARK: - Context Menu

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let otp = isFiltering ? filteredOTPs[indexPath.row] : otps[indexPath.row]

        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [weak self] _ in
            let copyAction = UIAction(title: "Copy Code", image: UIImage(systemName: "doc.on.doc")) { _ in
                guard let code = try? otp.generate() else { return }
                UIPasteboard.general.string = code
                Toast(text: "Copied to clipboard").show()
            }

            let editAction = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                self?.presentEditModal(for: indexPath)
            }

            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self?.confirmDelete(at: indexPath)
            }

            return UIMenu(children: [copyAction, editAction, deleteAction])
        }
    }

    // MARK: - Edit Modal

    private func presentEditModal(for indexPath: IndexPath) {
        let actualIndex: Int
        let otp: OTP

        if isFiltering {
            otp = filteredOTPs[indexPath.row]
            actualIndex = otps.firstIndex(where: { $0.id == otp.id }) ?? indexPath.row
        } else {
            otp = otps[indexPath.row]
            actualIndex = indexPath.row
        }

        let alert = UIAlertController(title: "Edit OTP", message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.text = otp.label
            textField.placeholder = "Label (e.g., Google)"
        }

        alert.addTextField { textField in
            textField.text = otp.user
            textField.placeholder = "User (e.g., user@example.com)"
        }

        alert.addTextField { [weak self] textField in
            textField.text = otp.maskedSecret
            textField.isEnabled = false
            textField.textColor = .secondaryLabel
            textField.placeholder = "Secret (tap to copy)"

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self?.secretFieldTapped(_:)))
            textField.addGestureRecognizer(tapGesture)
            textField.isUserInteractionEnabled = true
            textField.tag = actualIndex
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let newLabel = alert.textFields?[0].text
            let newUser = alert.textFields?[1].text

            do {
                try OTPLoader.update { stored in
                    guard let index = stored.firstIndex(where: { $0.secretData == otp.secretData }) else {
                        throw OTP.OTPError.unableToCreateOTP
                    }
                    stored[index] = try otp.copyWith(label: newLabel, user: newUser)
                }
                self.reloadOTPsFromStorage()
            } catch {
                Toast(text: "Failed to save changes").show()
            }
        })

        present(alert, animated: true)
    }

    @objc private func secretFieldTapped(_ gesture: UITapGestureRecognizer) {
        guard let textField = gesture.view as? UITextField else { return }
        let index = textField.tag
        guard index < otps.count else { return }

        UIPasteboard.general.string = otps[index].secretBase32
        Toast(text: "Secret copied to clipboard").show()
    }

    // MARK: - Delete Confirmation

    private func confirmDelete(at indexPath: IndexPath) {
        let otp = isFiltering ? filteredOTPs[indexPath.row] : otps[indexPath.row]

        let alert = UIAlertController(
            title: "Delete OTP (\(otp.label ?? otp.description))",
            message: "Are you sure? Be sure to disable 2FA before removing.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            do {
                try OTPLoader.update { stored in
                    stored.removeAll { $0.secretData == otp.secretData }
                }
            } catch {
                Toast(text: "Failed to delete").show()
            }
            self.reloadOTPsFromStorage()
        })

        present(alert, animated: true)
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

    @objc private func reloadOTPsFromStorage() {
        self.otps = OTPLoader.loadOTPs().sorted(by: { (a, b) -> Bool in
            a.label?.lowercased() ?? "" < b.label?.lowercased() ?? ""
        })
        AutoFillIdentities.sync(otps: otps)
        filterContentForSearchText(searchController.searchBar.text ?? "")
    }
    
    @objc private func updateOTPs() {
        if !self.tableView.isEditing {
            self.tableView.reloadData()
        }
    }

    @IBAction func unwindToOTPList(sender: UIStoryboardSegue) {
        if let source = sender.source as? ScannerViewController, let otp = source.otp {
            do {
                try OTPLoader.update { $0.append(otp) }
            } catch {
                Toast(text: "Failed to save new OTP").show()
                return
            }
            reloadOTPsFromStorage()
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


extension OTPTableViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            Toast(text: "Couldn't read backup file").show()
            return
        }

        let result = OTPBackup.merge(text, into: OTPLoader.loadOTPs())
        if result.added > 0 {
            do {
                try OTPLoader.saveOTPs(otps: result.merged)
            } catch {
                Toast(text: "Failed to save imported codes").show()
                return
            }
            reloadOTPsFromStorage()
        }

        var summary = "Imported \(result.added)"
        if result.duplicates > 0 { summary += ", \(result.duplicates) already present" }
        if result.invalidLines > 0 { summary += ", \(result.invalidLines) unreadable" }
        Toast(text: summary).show()
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
