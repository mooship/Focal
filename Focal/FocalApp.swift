import SwiftUI
import SwiftData

/// App entry point. Creates the SwiftData `ModelContainer` and `TaskStore` once and injects both
/// into the environment for `MainView` and its descendants.
@main
struct FocalApp: App {
    let modelContainer: ModelContainer
    let taskStore: TaskStore
    @AppStorage(DefaultsKey.colorScheme) private var colorSchemeRaw = DefaultsKey.colorSchemeSystem

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
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(taskStore)
                .preferredColorScheme(preferredScheme)
        }
        .modelContainer(modelContainer)
    }
}
