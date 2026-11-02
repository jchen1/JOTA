//
//  CredentialProviderViewController.swift
//  OTPCredentialProvider
//

import AuthenticationServices
import UIKit

class CredentialProviderViewController: ASCredentialProviderViewController {
    private enum Request {
        /// The user picked JOTA from the keyboard without a specific suggestion.
        case pick(hosts: [String])
        /// The user picked a suggestion JOTA registered for this site earlier.
        case identity(ASOneTimeCodeCredentialIdentity)
        /// The user chose AutoFill › JOTA from a text field's edit menu.
        case insertText
    }

    private struct Section {
        let heading: String
        let otps: [OTP]
    }

    private var request: Request?
    private var otps = [OTP]()
    private var sections = [Section]()
    private var hasAuthenticated = false
    private var timer: Timer?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let lockedView = UIStackView()

    // MARK: - ASCredentialProviderViewController

    override func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        request = .pick(hosts: serviceIdentifiers.map { OTPMatcher.normalizedHost($0.identifier) })
    }

    override func prepareInterfaceForUserChoosingTextToInsert() {
        request = .insertText
    }

    override func prepareInterfaceForExtensionConfiguration() {
        AutoFillIdentities.sync(otps: loadOTPs()) { [weak self] in
            DispatchQueue.main.async {
                self?.extensionContext.completeExtensionConfigurationRequest()
            }
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialRequest: ASCredentialRequest) {
        guard let identity = credentialRequest.credentialIdentity as? ASOneTimeCodeCredentialIdentity else {
            cancel(.credentialIdentityNotFound)
            return
        }
        request = .identity(identity)
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
        guard let identity = credentialRequest.credentialIdentity as? ASOneTimeCodeCredentialIdentity else {
            cancel(.credentialIdentityNotFound)
            return
        }
        guard AutoFillLock.isUnlocked else {
            cancel(.userInteractionRequired)
            return
        }
        guard let otp = loadOTPs().first(where: { $0.autofillRecordID == identity.recordIdentifier }) else {
            cancel(.credentialIdentityNotFound)
            return
        }
        complete(with: otp)
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setUpTableView()
        setUpLockedView()
        showLocked(true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAuthenticated else { return }
        authenticate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func setUpTableView() {
        let header = UINavigationBar()
        let item = UINavigationItem(title: "JOTA")
        item.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        header.items = [item]
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setUpLockedView() {
        let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
        icon.tintColor = .secondaryLabel
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40)

        let unlockButton = UIButton(type: .system)
        unlockButton.setTitle("Unlock JOTA", for: .normal)
        unlockButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        unlockButton.addTarget(self, action: #selector(unlockTapped), for: .touchUpInside)

        lockedView.axis = .vertical
        lockedView.alignment = .center
        lockedView.spacing = 16
        lockedView.addArrangedSubview(icon)
        lockedView.addArrangedSubview(unlockButton)
        lockedView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lockedView)
        NSLayoutConstraint.activate([
            lockedView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            lockedView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func showLocked(_ locked: Bool) {
        lockedView.isHidden = !locked
        tableView.isHidden = locked
    }

    // MARK: - Flow

    private func authenticate() {
        AutoFillLock.authenticate(reason: "Fill a verification code") { [weak self] success in
            guard let self = self, success else { return }
            self.hasAuthenticated = true
            self.proceed()
        }
    }

    private func proceed() {
        otps = loadOTPs()

        switch request {
        case .identity(let identity):
            if let otp = otps.first(where: { $0.autofillRecordID == identity.recordIdentifier }) {
                complete(with: otp)
            } else {
                // The OTP was deleted or changed since the suggestion was registered.
                AutoFillIdentities.sync(otps: otps)
                showPicker(hosts: [identity.serviceIdentifier.identifier])
            }
        case .pick(let hosts):
            let confident = AutoFillIdentities.confidentSuggestions(for: hosts, in: otps)
            if confident.count == 1, let otp = confident.first {
                remember(otp, hosts: hosts)
                complete(with: otp)
            } else {
                showPicker(hosts: hosts)
            }
        case .insertText, .none:
            showPicker(hosts: [])
        }
    }

    private func suggestions(for hosts: [String]) -> [OTP] {
        AutoFillIdentities.suggestions(for: hosts, in: otps)
    }

    private func showPicker(hosts: [String]) {
        if case .identity = request {
            request = .pick(hosts: hosts)
        }
        sections = []
        let suggested = suggestions(for: hosts)
        if !suggested.isEmpty {
            sections.append(Section(heading: "Suggestions", otps: suggested))
        }
        let sorted = otps.sorted { ($0.label ?? "").lowercased() < ($1.label ?? "").lowercased() }
        sections.append(Section(heading: "All Codes", otps: sorted))

        tableView.reloadData()
        showLocked(false)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshVisibleCodes()
        }
    }

    private func refreshVisibleCodes() {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            if let cell = tableView.cellForRow(at: indexPath) {
                configure(cell, with: sections[indexPath.section].otps[indexPath.row])
            }
        }
    }

    private func remember(_ otp: OTP, hosts: [String]) {
        AutoFillIdentities.remember(otp, forHosts: hosts, allOTPs: otps)
    }

    private func complete(with otp: OTP) {
        guard let code = try? otp.generate() else {
            cancel(.failed)
            return
        }
        if case .insertText = request {
            extensionContext.completeRequest(withTextToInsert: code, completionHandler: nil)
        } else {
            extensionContext.completeOneTimeCodeRequest(using: ASOneTimeCodeCredential(code: code), completionHandler: nil)
        }
    }

    private func cancel(_ code: ASExtensionError.Code) {
        extensionContext.cancelRequest(withError: ASExtensionError(code))
    }

    private func loadOTPs() -> [OTP] {
        OTPLoader.loadOTPs()
    }

    @objc private func cancelTapped() {
        cancel(.userCanceled)
    }

    @objc private func unlockTapped() {
        authenticate()
    }

    // MARK: - Cells

    private func configure(_ cell: UITableViewCell, with otp: OTP) {
        cell.textLabel?.text = otp.label?.isEmpty == false ? otp.label : "Untitled"
        cell.detailTextLabel?.text = otp.user
        cell.detailTextLabel?.textColor = .secondaryLabel

        let code = (try? otp.generate()) ?? "------"
        let codeLabel = (cell.accessoryView as? UILabel) ?? UILabel()
        codeLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .medium)
        codeLabel.text = code
        codeLabel.textColor = secondsLeft(for: otp) <= 5 ? .systemRed : .label
        codeLabel.sizeToFit()
        cell.accessoryView = codeLabel
    }

    private func secondsLeft(for otp: OTP) -> Int {
        guard otp.type() == .TOTP else { return Int.max }
        let period = otp.timeInterval ?? 30
        return period - Int(Date().timeIntervalSince1970) % period
    }
}

extension CredentialProviderViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].heading
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].otps.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OTPCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "OTPCell")
        configure(cell, with: sections[indexPath.section].otps[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let otp = sections[indexPath.section].otps[indexPath.row]
        if case .pick(let hosts) = request {
            remember(otp, hosts: hosts)
        }
        complete(with: otp)
    }
}
