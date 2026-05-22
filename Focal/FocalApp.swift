import SwiftUI
import SwiftData

@main
struct FocalApp: App {
    let modelContainer: ModelContainer
    let taskStore: TaskStore
    @AppStorage(NotificationManager.Key.colorScheme) private var colorSchemeRaw = "system"

    var preferredScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    init() {
        do {
            let schema = Schema([FocalTask.self])
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
