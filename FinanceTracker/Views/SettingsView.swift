import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Tools") {
                    NavigationLink {
                        InterestCalculatorView()
                    } label: {
                        Label("Interest Calculator", systemImage: "percent")
                    }
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("Manage Categories", systemImage: "tag")
                    }
                }
                Section("Data") {
                    NavigationLink {
                        DangerZoneView()
                    } label: {
                        Label("Danger Zone", systemImage: "exclamationmark.triangle")
                    }
                }
                Section("About") {
                    LabeledContent("App", value: "Finance Tracker")
                    LabeledContent("Mode", value: "Fully Offline")
                    Text("All data is stored on this device only. No network is ever contacted.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var newName = ""
    @State private var newType: TransactionType = .debit

    var body: some View {
        List {
            Section("Add") {
                TextField("Category name", text: $newName)
                Picker("Type", selection: $newType) {
                    ForEach(TransactionType.allCases) { t in Text(t.displayName).tag(t) }
                }.pickerStyle(.segmented)
                Button("Add") { add() }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("Existing") {
                ForEach(categories) { c in
                    HStack {
                        Image(systemName: c.systemImage).foregroundStyle(c.color)
                        Text(c.name)
                        Spacer()
                        Text(c.type.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Categories")
    }

    private func add() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        guard !categories.contains(where: { $0.name.lowercased() == n.lowercased() }) else { return }
        let c = Category(name: n, type: newType, colorHex: "#6B7280", systemImage: "tag")
        context.insert(c)
        try? context.save()
        newName = ""
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { context.delete(categories[i]) }
        try? context.save()
    }
}

struct DangerZoneView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]
    @State private var confirming = false

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    confirming = true
                } label: {
                    Label("Delete All Transactions", systemImage: "trash")
                }
            } footer: {
                Text("Removes \(transactions.count) transaction(s). Categories are preserved.")
            }
        }
        .navigationTitle("Danger Zone")
        .confirmationDialog("Delete all transactions?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func deleteAll() {
        for t in transactions { context.delete(t) }
        try? context.save()
    }
}
