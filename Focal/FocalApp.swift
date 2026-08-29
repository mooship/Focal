import SwiftUI
import SwiftData

/// App entry point. Creates the SwiftData `ModelContainer` and `TaskStore` once and injects both
/// into the environment for `MainView` and its descendants.
@main
struct FocalApp: App {
    let modelContainer: ModelContainer
    let taskStore: TaskStore
    @State private var appLock = AppLockManager()
    @AppStorage(DefaultsKey.colorScheme) private var colorSchemeRaw = DefaultsKey.colorSchemeSystem
    @AppStorage(DefaultsKey.appLockEnabled) private var appLockEnabled = false
    @Environment(\.scenePhase) private var scenePhase

    /// The user's chosen appearance from Settings; `nil` follows the system setting.
    var preferredScheme: ColorScheme? {
        switch colorSchemeRaw {
        case DefaultsKey.colorSchemeLight: return .light
        case DefaultsKey.colorSchemeDark: return .dark
        default: return nil
        }
    }

    init() {
        do {
            let schema = Schema([FocalTask.self, SubTask.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            modelContainer = container
            taskStore = TaskStore(modelContext: container.mainContext)
            Self.hardenFileProtection(of: config.url)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainView()
                    .environment(taskStore)
                    .preferredColorScheme(preferredScheme)
                if appLockEnabled && !appLock.isUnlocked {
                    LockScreenView(appLock: appLock)
                }
            }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard appLockEnabled else {
                return
            }
            switch newPhase {
            case .active:
                if !appLock.isUnlocked {
                    Task { await appLock.authenticate() }
                }
            default:
                appLock.lock()
            }
        }
    }

    /// Upgrades the SwiftData store's file protection from the default
    /// `.completeUntilFirstUserAuthentication` to `.completeUnlessOpen`, so task titles/notes stay
    /// encrypted at rest once the app isn't actively using the store, even after first unlock.
    /// `.complete` isn't used since it would deny reads while the device is locked but the app is
    /// still resident (e.g. under App Lock's own lock screen). Best-effort: sibling WAL/SHM files
    /// may not exist yet at first launch, and a failure here shouldn't block startup.
    private static func hardenFileProtection(of storeURL: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let path = storeURL.path + suffix
            guard fm.fileExists(atPath: path) else {
                continue
            }
            try? fm.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: path)
        }
    }
}
