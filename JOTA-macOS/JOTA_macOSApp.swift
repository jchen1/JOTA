//
//  JOTA_macOSApp.swift
//  JOTA-macOS
//
//  Created by Jeff Chen on 8/11/21.
//  Copyright © 2021 Jeff Chen. All rights reserved.
//

import SwiftUI

@main
struct JOTA_macOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ZStack {
                EmptyView()
            }.hidden()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var instance: AppDelegate! = nil

    var contentView: ContentView!
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        AppDelegate.instance = self

        // Create the SwiftUI view that provides the window contents.
        contentView = ContentView()

        // Create the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        // Create the status item
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        
        if let button = self.statusBarItem.button {
            button.image = NSImage(named: "Icon")
            button.action = #selector(togglePopover(_:))
        }
    }
    
    func hidePopover(_ sender: AnyObject?) {
        if self.popover.isShown {
            self.popover.performClose(sender)
            self.contentView.viewModel.setShown(shown: false)
        }
    }
    
    func showPopover(_ sender: AnyObject?) {
        if let button = self.statusBarItem.button {
            if !self.popover.isShown {
                NSApp.activate(ignoringOtherApps: true)
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                self.popover.contentViewController?.view.window?.makeKey()
                self.contentView.viewModel.setShown(shown: true)
            }
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if self.statusBarItem.button != nil {
            self.popover.isShown ? hidePopover(sender) : showPopover(sender)
        }
    }
    
}
