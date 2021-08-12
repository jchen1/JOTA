//
//  ContentView.swift
//  JOTA-macOS
//
//  Created by Jeff Chen on 8/11/21.
//  Copyright © 2021 Jeff Chen. All rights reserved.
//

import SwiftUI
import LocalAuthentication

class ContentViewShownModel: ObservableObject {
    @Published var isShown = false
    
    func setShown(shown: Bool) {
        isShown = shown
    }
}

struct ContentView: View {
    let AUTH_COOLDOWN_SECONDS: TimeInterval = 60 * 10 // 10 minutes
    
    @ObservedObject var shownModel = ContentViewShownModel()
    
    @State private var lastUnlockTime: Date? = nil
    @State private var isUnlocked = false
    @State var timeLeft = 30 - (Int64(Date().timeIntervalSince1970) % 30)
    @State var copyTime: Date? = nil
    @Environment(\.colorScheme) var currentMode
    
    let timer = Timer.publish(every: 0.1, on: .current, in: .common).autoconnect()
    
    let otps = OTPLoader.loadOTPs()
    
    @ViewBuilder
    var body: some View {
        ZStack {
            if currentMode == .dark {
                Color(red: 0.121, green: 0.121, blue: 0.18).ignoresSafeArea()
            } else {
                Color.white.ignoresSafeArea()
            }
        
            VStack {
                HStack {
                    Text("Two-Factor Tokens").font(Font.title3.bold()).foregroundColor(Color.white).frame(maxWidth: .infinity).padding(.top).padding(.bottom, 12)
                }.background(Color(red: 0.133, green: 0.895, blue: 0.422))
                
                if isUnlocked {
                    List {
                        ForEach(otps, id: \.id) { otp in
                            VStack {
                                Text(otp.label ?? "").font(Font.body.bold()).frame(maxWidth: .infinity, alignment: .leading)
                                Text(try! otp.generate()).font(.largeTitle).foregroundColor(timeLeft <= 5 ? .red : currentMode == .dark ? .white : .black).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 0.1)
                                HStack {
                                    Text(otp.user ?? "").frame(maxWidth: .infinity, alignment: .leading)
                                    Text(String(timeLeft)).onReceive(timer, perform: { now in
                                        timeLeft = 30 - (Int64(now.timeIntervalSince1970) % 30)
                                    }).frame(maxWidth: .infinity, alignment: .trailing)
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
                    Text("Locked...")
                    Spacer()
                }
            }
            .padding(.bottom)
            .onReceive(timer, perform: { now in
                if isUnlocked && now.timeIntervalSince(lastUnlockTime!) >= AUTH_COOLDOWN_SECONDS {
                    isUnlocked = false
                }
            })
            
            if copyTime != nil && Date().timeIntervalSince(copyTime!) < 2 {
                Text("Copied to clipboard!").frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .onReceive(shownModel.$isShown, perform: { shown in
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
            // it's possible, so go ahead and use it
            let reason = "unlock MFA codes"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                // authentication has now completed
                DispatchQueue.main.async {
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
        ContentView()
    }
}
