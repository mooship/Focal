import SwiftUI
import SwiftData

@main
struct FocalApp: App {
    let modelContainer: ModelContainer
    let taskStore: TaskStore

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
        }
        .modelContainer(modelContainer)
    }
}
