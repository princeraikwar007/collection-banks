import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.pie.fill") }

            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }

            ImportView()
                .tabItem { Label("Import", systemImage: "doc.text.viewfinder") }

            ReportsView()
                .tabItem { Label("Reports", systemImage: "chart.bar.doc.horizontal") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
