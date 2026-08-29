import Foundation
import SwiftData

extension ModelConfiguration {
    /// Upgrades the SwiftData store's file protection from the default
    /// `.completeUntilFirstUserAuthentication` to `.completeUnlessOpen`, so task titles/notes stay
    /// encrypted at rest once the app isn't actively using the store, even after first unlock.
    /// `.complete` isn't used since it would deny reads while the device is locked but the app is
    /// still resident (e.g. under App Lock's own lock screen). Best-effort: sibling WAL/SHM files
    /// may not exist yet at first launch, and a failure here shouldn't block startup.
    func hardenFileProtection() {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            guard fm.fileExists(atPath: path) else {
                continue
            }
            try? fm.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: path)
        }
    }
}
