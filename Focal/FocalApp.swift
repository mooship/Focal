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
            config.hardenFileProtection()
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
            appLock.handle(scenePhase: newPhase)
        }
    }
}
