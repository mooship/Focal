import Foundation
import LocalAuthentication
import SwiftUI

/// Gates app content behind Face ID/Touch ID/passcode when App Lock is enabled in Settings.
@Observable
final class AppLockManager {
    private(set) var isUnlocked = false
    private(set) var isAuthenticating = false

    /// Applies lock policy for a `scenePhase` transition: re-authenticates on becoming active,
    /// otherwise locks immediately (including on `.inactive`, so a backgrounding app switcher
    /// snapshot never shows task content). `FocalApp` forwards every change here unconditionally.
    func handle(scenePhase: ScenePhase) {
        if scenePhase == .active {
            Task { await authenticate() }
        } else {
            lock()
        }
    }

    /// Immediately hides app content behind the lock screen.
    func lock() {
        isUnlocked = false
    }

    /// Prompts for Face ID/Touch ID/passcode. Unlocks without prompting if the device has no
    /// passcode set, since a lock the user can never pass would just deny access to their tasks.
    func authenticate() async {
        guard !isAuthenticating, !isUnlocked else {
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isUnlocked = true
            return
        }
        let reason = String(localized: "Unlock Focal")
        let success = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
        isUnlocked = success
    }
}
