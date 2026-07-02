import SwiftUI
import SwiftData

@main
struct FinanceTrackerApp: App {
    // Single SwiftData container held for the app lifetime.
    // All storage lives on-device (Application Support). No CloudKit, no network.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            CategorySeeder.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
