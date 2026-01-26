# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JOTA (Jeff's One Time password Authenticator) is a multi-platform 2FA authenticator app for iOS and macOS. It generates TOTP and HOTP codes, stores credentials securely in Keychain with iCloud sync, and supports QR code scanning for credential import.

## Build Commands

```bash
# Install dependencies
pod install

# Build iOS app
xcodebuild -workspace JOTA.xcworkspace -scheme JOTA -sdk iphonesimulator build

# Build macOS app
xcodebuild -workspace JOTA.xcworkspace -scheme JOTA-macOS build

# Run tests
xcodebuild -workspace JOTA.xcworkspace -scheme JOTA -sdk iphonesimulator test
```

Open `JOTA.xcworkspace` (not `.xcodeproj`) in Xcode for development.

## Architecture

### Targets
- **JOTA**: Main iOS app (iOS 10.0+)
- **JOTA-macOS**: macOS app using SwiftUI (macOS 12.0+)
- **OTPAutoFill**: iOS AutoFill extension for credential services

### Core Files (JOTA/)
- `OTP.swift` - Data model for OTP entries. Supports TOTP/HOTP, multiple algorithms (SHA1/256/512), configurable digits and periods. Parses `otpauth://` URLs.
- `OTPLoader.swift` - Persistence layer using KeychainAccess with iCloud sync. Handles migration from UserDefaults to Keychain. Access group: `45A594478C.dev.jeffchen.JOTA`
- `OTPTableViewController.swift` - Main iOS UI with search, OTP generation, and clipboard copy
- `ScannerViewController.swift` - QR code scanner for importing OTP credentials
- `OTPTableViewCell.swift` - Custom cell for displaying OTP entries with countdown

### macOS (JOTA-macOS/)
- `JOTA_macOSApp.swift` - SwiftUI app entry point
- `ContentView.swift` - Main SwiftUI view

### Dependencies (CocoaPods)
- **KeychainAccess**: Secure credential storage with iCloud sync
- **SwiftOTP**: TOTP/HOTP generation
- **Toaster**: Toast notifications (iOS only)
- **Introspect**: SwiftUI introspection (macOS only)

## Data Storage

OTP credentials are stored in Keychain with:
- Service: `group.dev.jeffchen.jota`
- Access Group: `45A594478C.dev.jeffchen.JOTA`
- iCloud sync enabled (`.synchronizable(true)`)

The `OTP` class uses `NSCoding` for serialization. Class name mappings handle cross-target compatibility (JOTA, JOTA-macOS, jota).
