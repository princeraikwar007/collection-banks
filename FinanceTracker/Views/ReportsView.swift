import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            List {
                summarySection
                monthlySection
                categorySection
                exportSection
            }
            .navigationTitle("Reports")
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private var totals: ReportEngine.Totals { ReportEngine.totals(transactions) }
    private var months: [ReportEngine.MonthlyBucket] { ReportEngine.byMonth(transactions) }
    private var byCatExpense: [ReportEngine.CategoryBreakdown] { ReportEngine.byCategory(transactions, type: .debit) }
    private var byCatIncome: [ReportEngine.CategoryBreakdown] { ReportEngine.byCategory(transactions, type: .credit) }

    private var summarySection: some View {
        Section("Summary") {
            LabeledContent("Transactions", value: "\(totals.count)")
            LabeledContent("Total Credit", value: Money.string(totals.credit))
            LabeledContent("Total Debit",  value: Money.string(totals.debit))
            LabeledContent("Balance",      value: Money.string(totals.balance))
        }
    }

    @ViewBuilder
    private var monthlySection: some View {
        if !months.isEmpty {
            Section("Monthly") {
                Chart(months) { m in
                    BarMark(x: .value("Month", m.displayMonth), y: .value("Credit", m.credit))
                        .foregroundStyle(.green)
                    BarMark(x: .value("Month", m.displayMonth), y: .value("Debit", m.debit))
                        .foregroundStyle(.red)
                }
                .frame(height: 200)

                ForEach(months) { m in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.displayMonth).font(.subheadline.bold())
                        HStack {
                            Text("+ \(Money.string(m.credit))").foregroundStyle(.green).font(.caption)
                            Text("- \(Money.string(m.debit))").foregroundStyle(.red).font(.caption)
                            Spacer()
                            Text("Net \(Money.signedString(m.net))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(m.net >= 0 ? .green : .red)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        if !byCatExpense.isEmpty {
            Section("Expenses by Category") {
                ForEach(byCatExpense) { c in
                    HStack {
                        Text(c.category)
                        Spacer()
                        Text(Money.string(c.total)).monospacedDigit().foregroundStyle(.red)
                    }
                }
            }
        }
        if !byCatIncome.isEmpty {
            Section("Income by Category") {
                ForEach(byCatIncome) { c in
                    HStack {
                        Text(c.category)
                        Spacer()
                        Text(Money.string(c.total)).monospacedDigit().foregroundStyle(.green)
                    }
                }
            }
        }
    }

    private var exportSection: some View {
        Section("Export") {
            Button {
                exportCSV()
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            Button {
                exportText()
            } label: {
                Label("Export Text Report", systemImage: "doc.plaintext")
            }
        }
    }

    private func exportCSV() {
        let csv = CSVExporter.csv(from: transactions)
        do {
            let url = try CSVExporter.writeTempFile(csv, name: "transactions-\(DateFmt.iso.string(from: Date())).csv")
            shareItem = ShareItem(url: url)
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func exportText() {
        let text = ReportEngine.textReport(transactions)
        do {
            let url = try CSVExporter.writeTempFile(text, name: "report-\(DateFmt.iso.string(from: Date())).txt")
            shareItem = ShareItem(url: url)
        } catch {
            print("Export failed: \(error)")
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    ReportsView().modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
