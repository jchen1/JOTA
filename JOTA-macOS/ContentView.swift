//
//  ContentView.swift
//  JOTA-macOS
//
//  Created by Jeff Chen on 8/11/21.
//  Copyright © 2021 Jeff Chen. All rights reserved.
//

import SwiftUI
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

struct ContentView: View {
    let AUTH_COOLDOWN_SECONDS: TimeInterval = 60 * 10 // 10 minutes
    
    @ObservedObject var viewModel = ContentViewModel()
    
    @State private var lastUnlockTime: Date? = nil
    @State private var isUnlocked = false
    @State var timeLeft = 30 - (Int64(Date().timeIntervalSince1970) % 30)
    @State var copyTime: Date? = nil
    var isPreview: Bool
    
    @Environment(\.colorScheme) var currentMode
    var primary = Color.black
    
    let timer = Timer.publish(every: 0.1, on: .current, in: .common).autoconnect()
    
    let otps = OTPLoader.loadOTPs()
    
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        self.primary = currentMode == .dark ? Color.white : Color.black
    }
    
    @ViewBuilder
    var body: some View {
        ZStack {
            if currentMode == .dark {
                // apparently what a `List` uses in dark mode
                Color(red: 0.121, green: 0.121, blue: 0.18).ignoresSafeArea()
            } else {
                Color.white.ignoresSafeArea()
            }
            VStack {
                if isUnlocked || isPreview {
                    List {
                        HStack {
                            Text("Two-Factor Tokens").font(.largeTitle).fontWeight(.bold).foregroundColor(primary).padding(.bottom)
                            Spacer()
                        }
                        ForEach(otps, id: \.id) { otp in
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
                            }.frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture {
                                let pasteboard = NSPasteboard.general
                                pasteboard.declareTypes([.string], owner: nil)
                                pasteboard.setString(try! otp.generate(), forType: .string)
                                copyTime = Date()
                            }
                        }
                    }
                } else {
                    Spacer()
                    Text("Locked...")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    Button(action: {}) {
                        Image(systemName: "plus.circle").foregroundColor(.white).padding(.leading).font(.title2).padding(.vertical, 10)
                    }.buttonStyle(PlainButtonStyle())
                    let text = copyTime != nil && Date().timeIntervalSince(copyTime!) < 2 ? "Copied to clipboard!" : ""
                    
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
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // keep the popover open while touchid runs...
            AppDelegate.instance.popover.behavior = .applicationDefined
            
            self.viewModel.setAuthenticating(authenticating: true)
            // it's possible, so go ahead and use it
            let reason = "unlock MFA codes"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                // authentication has now completed
                DispatchQueue.main.async {
                    
                    // allow the popover to hide on click again
                    NSApp.activate(ignoringOtherApps: true)
                    AppDelegate.instance.popover.behavior = .transient

                    self.viewModel.setAuthenticating(authenticating: false)
                    if success {
                        self.lastUnlockTime = Date()
                        self.isUnlocked = true
                    } else {
                        // there was a problem
                    }
                }
            }
        } else {
            // todo...
            self.lastUnlockTime = Date()
            self.isUnlocked = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(isPreview: true)
    }
}
