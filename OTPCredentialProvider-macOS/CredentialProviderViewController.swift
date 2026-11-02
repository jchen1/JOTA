//
//  CredentialProviderViewController.swift
//  OTPCredentialProvider-macOS
//

import AuthenticationServices
import SwiftUI

class CredentialProviderViewController: ASCredentialProviderViewController {
    private enum Request {
        /// The user picked JOTA from AutoFill without a specific suggestion.
        case pick(hosts: [String])
        /// The user picked a suggestion JOTA registered for this site earlier.
        case identity(ASOneTimeCodeCredentialIdentity)
    }

    private var request: Request?
    private var otps = [OTP]()
    private let model = PickerModel()

    // MARK: - ASCredentialProviderViewController

    override func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        request = .pick(hosts: serviceIdentifiers.map { OTPMatcher.normalizedHost($0.identifier) })
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
        guard let otp = OTPLoader.loadOTPs().first(where: { $0.autofillRecordID == identity.recordIdentifier }) else {
            cancel(.credentialIdentityNotFound)
            return
        }
        complete(with: otp)
    }

    override func prepareInterfaceForExtensionConfiguration() {
        AutoFillIdentities.sync(otps: OTPLoader.loadOTPs()) { [weak self] in
            DispatchQueue.main.async {
                self?.extensionContext.completeExtensionConfigurationRequest()
            }
        }
    }

    // MARK: - View lifecycle

    override func loadView() {
        model.onSelect = { [weak self] otp in self?.select(otp) }
        model.onCancel = { [weak self] in self?.cancel(.userCanceled) }
        let hosting = NSHostingView(rootView: PickerView(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: 380, height: 440)
        view = hosting
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        proceed()
    }

    // MARK: - Flow

    private func proceed() {
        otps = OTPLoader.loadOTPs()

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
                AutoFillIdentities.remember(otp, forHosts: hosts, allOTPs: otps)
                complete(with: otp)
            } else {
                showPicker(hosts: hosts)
            }
        case .none:
            showPicker(hosts: [])
        }
    }

    private func showPicker(hosts: [String]) {
        request = .pick(hosts: hosts)
        let suggested = AutoFillIdentities.suggestions(for: hosts, in: otps)
        let suggestedIDs = Set(suggested.map(\.autofillRecordID))
        model.suggestions = suggested
        model.others = otps
            .filter { !suggestedIDs.contains($0.autofillRecordID) }
            .sorted { ($0.label ?? "").lowercased() < ($1.label ?? "").lowercased() }
        model.isLoaded = true
    }

    private func select(_ otp: OTP) {
        if case .pick(let hosts) = request {
            AutoFillIdentities.remember(otp, forHosts: hosts, allOTPs: otps)
        }
        complete(with: otp)
    }

    private func complete(with otp: OTP) {
        guard let code = try? otp.generate() else {
            cancel(.failed)
            return
        }
        extensionContext.completeOneTimeCodeRequest(using: ASOneTimeCodeCredential(code: code), completionHandler: nil)
    }

    private func cancel(_ code: ASExtensionError.Code) {
        extensionContext.cancelRequest(withError: ASExtensionError(code))
    }
}

// MARK: - Picker UI

private final class PickerModel: ObservableObject {
    @Published var isLoaded = false
    @Published var suggestions = [OTP]()
    @Published var others = [OTP]()
    var onSelect: (OTP) -> Void = { _ in }
    var onCancel: () -> Void = {}
}

private struct PickerView: View {
    @ObservedObject var model: PickerModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("JOTA").font(.headline)
                Spacer()
                Button("Cancel", action: model.onCancel).keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()

            if !model.isLoaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    List {
                        if !model.suggestions.isEmpty {
                            Section("Suggestions") {
                                ForEach(model.suggestions, id: \.autofillRecordID) { otp in
                                    row(otp, now: context.date)
                                }
                            }
                        }
                        Section(model.suggestions.isEmpty ? "All Codes" : "Other Codes") {
                            ForEach(model.others, id: \.autofillRecordID) { otp in
                                row(otp, now: context.date)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 340, minHeight: 360)
    }

    private func row(_ otp: OTP, now: Date) -> some View {
        Button {
            model.onSelect(otp)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(otp.label?.isEmpty == false ? otp.label! : "Untitled").fontWeight(.semibold)
                    if let user = otp.user, !user.isEmpty {
                        Text(user).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text((try? otp.generate()) ?? "------")
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(secondsLeft(otp, now: now) <= 5 ? Color.red : Color.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func secondsLeft(_ otp: OTP, now: Date) -> Int {
        guard let period = otp.timeInterval else { return Int.max }
        return period - Int(now.timeIntervalSince1970) % period
    }
}
