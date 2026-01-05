//
//  AppEnvironment.swift
//  kodi.remote.xbmc
//
//  Detects app environment (TestFlight, Debug, App Store)
//

import Foundation

enum AppEnvironment {
    /// Returns true if the app is running from TestFlight
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// Returns true if the app is running in Debug mode
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Returns true if Pro features should be unlocked (TestFlight or Debug)
    static var shouldUnlockPro: Bool {
        isTestFlight || isDebug
    }

    /// Automatically unlock Pro features if running in TestFlight or Debug
    static func configureProUnlock() {
        if shouldUnlockPro {
            UserDefaults.standard.set(true, forKey: "isProUnlocked")
        }
    }
}
