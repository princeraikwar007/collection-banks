import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var showingPicker = false
    @State private var parseReport: PDFStatementParser.ParseReport?
    @State private var selectedIndices: Set<Int> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack {
                if let report = parseReport {
                    reviewList(report: report)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Import PDF")
            .toolbar {
                if parseReport != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") { parseReport = nil; selectedIndices = [] }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import (\(selectedIndices.count))") { importSelected() }
                            .disabled(selectedIndices.isEmpty)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFile(result)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { msg in
                Text(msg)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Import a Bank Statement PDF")
                .font(.title2.bold())
            Text("Parsing runs fully on-device using PDFKit. Nothing leaves your iPhone.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            Button {
                showingPicker = true
            } label: {
                Label("Choose PDF", systemImage: "folder")
                    .padding(.horizontal, 24).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    @ViewBuilder
    private func reviewList(report: PDFStatementParser.ParseReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(report.sourceName).font(.headline).padding(.horizontal)
            Text("Matched \(report.linesMatched) of \(report.totalLinesScanned) lines")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal)

            HStack {
                Button("Select All") { selectedIndices = Set(report.transactions.indices) }
                Button("Deselect All") { selectedIndices = [] }
            }.font(.footnote).padding(.horizontal)

            List {
                ForEach(Array(report.transactions.enumerated()), id: \.offset) { idx, tx in
                    HStack(alignment: .top) {
                        Image(systemName: selectedIndices.contains(idx) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedIndices.contains(idx) ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.desc).lineLimit(2).font(.subheadline)
                            Text(DateFmt.short.string(from: tx.date))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.signedString(tx.type == .credit ? tx.amount : -tx.amount))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(tx.type == .credit ? .green : .red)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(idx) }
                }
            }
        }
    }

    private func toggle(_ idx: Int) {
        if selectedIndices.contains(idx) { selectedIndices.remove(idx) }
        else { selectedIndices.insert(idx) }
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            if let report = PDFStatementParser.parse(fileURL: url) {
                parseReport = report
                selectedIndices = Set(report.transactions.indices)
            } else {
                errorMessage = "Could not read that PDF. It may be encrypted or image-only (scanned)."
            }
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }

    private func importSelected() {
        guard let report = parseReport else { return }
        for idx in selectedIndices.sorted() {
            let tx = report.transactions[idx]
            let cat = PDFStatementParser.suggestCategory(
                for: tx.desc, type: tx.type, available: categories
            )
            let model = Transaction(
                date: tx.date,
                amount: tx.amount,
                type: tx.type,
                desc: tx.desc,
                notes: "",
                categoryName: cat,
                source: "pdf-import:\(report.sourceName)"
            )
            context.insert(model)
        }
        try? context.save()
        parseReport = nil
        selectedIndices = []
    }
}

#Preview {
    ImportView().modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
