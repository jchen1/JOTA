//
//  ContentView.swift
//  JOTA-macOS
//
//  Created by Jeff Chen on 8/11/21.
//  Copyright © 2021 Jeff Chen. All rights reserved.
//

import SwiftUI
import Introspect
import LocalAuthentication

class ContentViewModel: ObservableObject {
    @Published var isShown = false
    @Published var isAuthenticating = false
    
    func setShown(shown: Bool) {
        isShown = shown
    }
    
    func setAuthenticating(authenticating: Bool) {
        isAuthenticating = authenticating
    }
}

extension List {
  /// List on macOS uses an opaque background with no option for
  /// removing/changing it. listRowBackground() doesn't work either.
  /// This workaround works because List is backed by NSTableView.
  func removeBackground() -> some View {
    return introspectTableView { tableView in
        tableView.backgroundColor = .clear
        tableView.enclosingScrollView!.drawsBackground = false
    
    }
  }
}

extension NSTextField {
    /// Disables focus ring for all NSTextFields
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}

let green = Color(red: 0.133, green: 0.895, blue: 0.422)


struct TokenGroupBoxStyle: GroupBoxStyle {
    var background: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .padding(1)
            .background(background)
    }
}

struct ContentView: View {
    let AUTH_COOLDOWN_SECONDS: TimeInterval = 60 * 10 // 10 minutes
    
    @ObservedObject var viewModel = ContentViewModel()
    
    @State private var lastUnlockTime: Date? = nil
    @State private var isUnlocked = false
    @State private var timeLeft = 30 - (Int64(Date().timeIntervalSince1970) % 30)
    @State private var toastTime: Date? = nil
    @State private var toastText: String = ""
    @State private var query: String = ""
    @FocusState private var queryFocused: Bool
    
    var isPreview: Bool
    
    @Environment(\.colorScheme) var currentMode
    var primary = Color.black
    var listBackground = Color.white
    
    let timer = Timer.publish(every: 0.1, on: .current, in: .common).autoconnect()
    
    
    @State var otps = OTPLoader.loadOTPs()
    
    var filteredOtps: [OTP] {
        if query.isEmpty {
            return otps
        } else {
            return otps.filter { $0.label?.lowercased().contains(query.lowercased()) ?? false || $0.user?.lowercased().contains(query.lowercased()) ?? false }
        }
    }
    
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        self.primary = currentMode == .dark ? Color.white : Color.black
        self.listBackground = currentMode == .dark ? Color(red: 0.121, green: 0.121, blue: 0.18) : Color.white
    }
    
    @ViewBuilder
    var body: some View {
        ZStack {
            green.ignoresSafeArea()
            VStack {
                HStack {
                    Text("Two-Factor Tokens").font(.largeTitle).fontWeight(.bold).foregroundColor(Color.white).padding(.top)
                    Spacer()
                }.padding([.horizontal, .top])
                
                GroupBox {
                    if isUnlocked || isPreview {
                        TextField(
                            "Search",
                            text: $query
                        )
                        .focused($queryFocused)
                        .onAppear {
                            queryFocused = true
                        }
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10.0)
                        .padding(.vertical, 4.0)
                        .background(Color.clear)
                    
                        
                        List {
                            ForEach(Array(filteredOtps.enumerated()), id: \.1.id) { index, otp in
                                let copyAction = {
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.declareTypes([.string], owner: nil)
                                    pasteboard.setString(try! otp.generate(), forType: .string)
                                    toastTime = Date()
                                    toastText = "Copied to clipboard!"
                                }
                                VStack {
                                    Text(otp.label ?? "").font(.body).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                                    Text(try! otp.generate()).font(.largeTitle).fontWeight(.semibold).foregroundColor(timeLeft <= 5 ? .red : primary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 0.1)
                                    HStack {
                                        Text(otp.user ?? "").frame(maxWidth: .infinity, alignment: .leading)
                                        Text(String(timeLeft)).onReceive(timer, perform: { now in
                                            timeLeft = 30 - (Int64(now.timeIntervalSince1970) % 30)
                                        }).frame(alignment: .trailing)
                                    }.frame(maxWidth: .infinity)
                                    
                                    Divider()
                                }.listRowBackground(Color.clear).frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture(perform: copyAction).contextMenu {
                                    Button("Copy to clipboard", action: copyAction)
                                    Button("Delete", action: {
                                        otps.remove(at: index)
                                        try! OTPLoader.saveOTPs(otps: otps)
                                    })
                                }
                            }
                            
                        }
                        .removeBackground()
                    } else {
                        Spacer()
                        Text("Locked...")
                            .font(.headline)
                        Spacer()
                    }
                }
                .groupBoxStyle(TokenGroupBoxStyle()).padding(.horizontal, 10.0)
                
                HStack {
                    Button(action: {
                        // leave popover open
                        AppDelegate.instance.popover.behavior = .applicationDefined

                        let panel = NSOpenPanel()
                        panel.message = "Choose Image"
                        panel.prompt = "Choose"
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.canCreateDirectories = false
                        panel.canChooseFiles = true
                        panel.allowedFileTypes = ["png", "jpg", "jpeg", "gif"]
                        panel.begin { (result) -> Void in
                            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                                let path = panel.url!.path
                                let img = CIImage(contentsOf: URL(fileURLWithPath: path))
                                let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)
                                if let features = detector?.features(in: img!) {
                                    if features.count == 0 {
                                        toastTime = Date()
                                        toastText = "Couldn't add OTP."
                                    }
                                    for feature in features {
                                        if let otp = try? OTP(url: (feature as! CIQRCodeFeature).messageString!) {
                                            try! OTPLoader.saveOTPs(otps: otps + [otp])
                                            otps = OTPLoader.loadOTPs()
                                            toastTime = Date()
                                            toastText = "Added OTP!"
                                        }
                                    }
                                } else {
                                    toastTime = Date()
                                    toastText = "Couldn't add OTP."
                                }
                            }
                            AppDelegate.instance.popover.behavior = .transient

                        }
                    }) {
                        Image(systemName: "plus.circle").foregroundColor(.white).padding(.leading).font(.title2).padding(.vertical, 10)
                    }.buttonStyle(PlainButtonStyle())
                    let text = toastTime != nil && Date().timeIntervalSince(toastTime!) < 2 ? toastText : ""
                    
                    Spacer()
                    Text(text).padding(.vertical, 10).foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        NSApp.terminate(self)
                    }) {
                        Image(systemName: "xmark.circle").foregroundColor(.white).padding(.trailing).font(.title2).padding(.vertical, 10)
                    }.buttonStyle(PlainButtonStyle())
                }
                .background(Color(red: 0.133, green: 0.895, blue: 0.422))
            }
            .onReceive(timer, perform: { now in
                if isUnlocked && now.timeIntervalSince(lastUnlockTime!) >= AUTH_COOLDOWN_SECONDS {
                    isUnlocked = false
                }
            })
        }
        .onReceive(viewModel.$isShown, perform: { shown in
            if shown && !isUnlocked {
                authenticate()
            }
        })
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?

        // check whether biometric authentication is possible
//        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
//            // keep the popover open while touchid runs...
//            AppDelegate.instance.popover.behavior = .applicationDefined
//
//            self.viewModel.setAuthenticating(authenticating: true)
//            // it's possible, so go ahead and use it
//            let reason = "unlock MFA codes"
//
//            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
//                // authentication has now completed
//                DispatchQueue.main.async {
//
//                    // allow the popover to hide on click again
//                    NSApp.activate(ignoringOtherApps: true)
//                    AppDelegate.instance.popover.behavior = .transient
//
//                    self.viewModel.setAuthenticating(authenticating: false)
//                    if success {
//                        self.lastUnlockTime = Date()
//                        self.isUnlocked = true
//                    } else {
//                        // there was a problem
//                    }
//                }
//            }
//        } else {
//            // todo...
//            self.lastUnlockTime = Date()
//            self.isUnlocked = true
//        }
        
        self.lastUnlockTime = Date()
        self.isUnlocked = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(isPreview: true)
    }
}
