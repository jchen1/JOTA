//
//  ContentView.swift
//  JOTA-macOS
//
//  Created by Jeff Chen on 8/11/21.
//  Copyright © 2021 Jeff Chen. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State var timeLeft = 30 - (Int64(Date().timeIntervalSince1970) % 30)
    @State var copyTime: Date? = nil
    
    let timer = Timer.publish(every: 0.1, on: .current, in: .common).autoconnect()
    
    let otps = OTPLoader.loadOTPs()
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack {
                List {
                    ForEach(otps, id: \.id) { otp in
                        VStack {
                            Text(otp.label ?? "").font(Font.body.bold()).frame(maxWidth: .infinity, alignment: .leading)
                            Text(try! otp.generate()).font(.largeTitle).foregroundColor(timeLeft <= 5 ? .red : .black).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 0.1)
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
                .navigationTitle("Two-Factor Tokens")
                
                Text("Copied to clipboard!").foregroundColor((copyTime != nil) ? Date().timeIntervalSince(copyTime!) < 2 ? Color.black : Color.white : Color.white)
            }.padding(.bottom)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
