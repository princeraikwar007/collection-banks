# Finance Tracker (Offline iOS App)

A fully offline personal-finance iOS app built with **SwiftUI + SwiftData + PDFKit + Swift Charts**. Everything — storage, PDF parsing, categorization, reports — runs on the device. There are no network calls anywhere in the code.

## Features

- Track all money transactions (add / edit / delete)
- Total credit, total debit, and remaining balance on the Dashboard
- Interest calculator (simple + compound, configurable compounding periods)
- Import bank-statement PDFs via `PDFKit` (on-device text extraction)
- Automatic transaction detection from PDF text using date + amount heuristics
- Automatic category suggestions from keyword rules (Salary, Rent, Food, etc.)
- Search transactions by description, category, or notes
- Reports: monthly totals + expenses/income by category (Swift Charts)
- Export CSV and text reports via the share sheet
- Fully offline: SwiftData store on-device, no CloudKit, no iCloud sync, no networking libraries

## Requirements

- Xcode 15 or later
- iOS 17 SDK (SwiftData + `ContentUnavailableView` require iOS 17+)
- A Mac to build. This project ships as source — no pre-built binary.

## Setup in Xcode

1. Open Xcode → **File ▸ New ▸ Project…**
2. Choose **iOS ▸ App**. Set:
   - Product Name: `FinanceTracker`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we bring our own SwiftData setup)
   - Include Tests: optional
3. When Xcode creates the project, **delete** the auto-generated `ContentView.swift` and `FinanceTrackerApp.swift`.
4. Drag the `FinanceTracker/` source folder from this repo into the Xcode project navigator. Check **Copy items if needed** and **Create groups**.
5. Replace the auto-generated `Info.plist` with the one under `FinanceTracker/Resources/Info.plist` (or merge the `CFBundleDocumentTypes` entry so PDFs can be opened from Files).
6. Under the target's **Signing & Capabilities**, sign with your Apple ID (Personal Team is fine for local install).
7. Set the deployment target to **iOS 17.0**.
8. Build & run on a simulator or your own iPhone.

## Project layout

```
FinanceTracker/
├── FinanceTrackerApp.swift           # App entry, SwiftData ModelContainer
├── Models/
│   ├── Transaction.swift             # @Model Transaction (credit/debit, amount, date, category)
│   └── Category.swift                # @Model Category + default seeder
├── Services/
│   ├── PDFStatementParser.swift      # On-device PDFKit parser + keyword categorizer
│   ├── CSVExporter.swift             # Transactions → CSV
│   ├── ReportEngine.swift            # Totals, monthly + category aggregations, text report
│   └── InterestCalculator.swift      # Simple + compound interest
├── Utilities/
│   └── Formatters.swift              # Currency + date formatters
├── Views/
│   ├── RootTabView.swift             # 5-tab TabView shell
│   ├── DashboardView.swift           # Balance, credit/debit, top categories, recent tx
│   ├── TransactionsView.swift        # List + search + filter + add/edit/delete
│   ├── AddEditTransactionView.swift  # Form for creating/updating a Transaction
│   ├── ImportView.swift              # PDF picker → review parsed rows → import
│   ├── ReportsView.swift             # Monthly + category charts + CSV/text export
│   ├── SettingsView.swift            # Categories mgmt, danger zone, about
│   └── InterestCalculatorView.swift  # Interest calculator UI
└── Resources/
    ├── Info.plist
    └── FinanceTracker.entitlements
```

## How the PDF import works

1. User taps **Import PDF** and picks a bank statement from Files or iCloud Drive (the file itself may live in iCloud, but no data is uploaded — the OS just hands us the file bytes).
2. `PDFKit`'s `PDFDocument` extracts text from every page on-device.
3. Each line is scanned by `PDFStatementParser`:
   - Regex-detect a date in the leading part of the line (multiple date formats supported).
   - Regex-detect the rightmost monetary amount, honoring `CR`/`DR`, parentheses, and `-` for sign.
   - Description is whatever sits between the date and the amount.
4. Detected rows are shown in a review list. The user can deselect any noise before importing.
5. Selected rows are inserted as `Transaction` records with a keyword-based category guess (fully local — no ML, no network).

Encrypted PDFs and image-only scanned PDFs aren't parseable without OCR — the UI shows a friendly error in those cases.

## Offline guarantee

- No `URLSession`, no `Network.framework`, no third-party analytics/tracking, no CloudKit.
- SwiftData `ModelConfiguration` is initialized with `cloudKitDatabase: .none`.
- Currency formatting uses `Locale.current` (no server lookups).
- Charts are drawn with Apple's built-in Swift Charts.

## Extending

- Add new keyword rules in `PDFStatementParser.suggestCategory(for:type:available:)`.
- Add new date formats in `PDFStatementParser.datePatterns` if your bank uses an unusual layout.
- To support recurring bills, add a `RecurrenceRule` field to `Transaction` and a background scheduler in `FinanceTrackerApp.swift`.
