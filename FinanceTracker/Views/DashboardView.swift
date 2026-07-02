import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    balanceCard
                    creditDebitRow
                    categoryChart
                    recentSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .background(Color(.systemGroupedBackground))
        }
    }

    private var totals: ReportEngine.Totals { ReportEngine.totals(transactions) }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remaining Balance").font(.caption).foregroundStyle(.secondary)
            Text(Money.string(totals.balance))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(totals.balance >= 0 ? .primary : .red)
            Text("\(totals.count) transactions").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var creditDebitRow: some View {
        HStack(spacing: 12) {
            statCard(title: "Total Credit", value: totals.credit, color: .green, icon: "arrow.down.left.circle.fill")
            statCard(title: "Total Debit",  value: totals.debit,  color: .red,   icon: "arrow.up.right.circle.fill")
        }
    }

    private func statCard(title: String, value: Double, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(color)
            Text(Money.string(value)).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    @ViewBuilder
    private var categoryChart: some View {
        let breakdown = ReportEngine.byCategory(transactions, type: .debit).prefix(6)
        if breakdown.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Top Expense Categories").font(.headline)
                Chart(Array(breakdown)) { item in
                    BarMark(
                        x: .value("Total", item.total),
                        y: .value("Category", item.category)
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                }
                .frame(height: max(180, CGFloat(breakdown.count) * 32))
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Transactions").font(.headline)
            if transactions.isEmpty {
                Text("No transactions yet. Add one from the Transactions tab or import a bank PDF.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(transactions.prefix(6)) { t in
                    TransactionRow(transaction: t)
                    Divider()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.desc).lineLimit(1).font(.subheadline)
                HStack(spacing: 6) {
                    Text(transaction.categoryName).font(.caption).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text(DateFmt.short.string(from: transaction.date)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Money.signedString(transaction.signedAmount))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(transaction.type == .credit ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView().modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
