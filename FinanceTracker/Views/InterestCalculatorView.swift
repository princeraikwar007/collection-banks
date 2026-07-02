import SwiftUI

struct InterestCalculatorView: View {
    @State private var kind: InterestCalculator.Kind = .compound
    @State private var principalText = "1000"
    @State private var rateText = "5.0"
    @State private var yearsText = "3"
    @State private var compoundsText = "12"

    var body: some View {
        Form {
            Section("Method") {
                Picker("Method", selection: $kind) {
                    ForEach(InterestCalculator.Kind.allCases) { k in
                        Text(k.displayName).tag(k)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Inputs") {
                LabeledField(title: "Principal", text: $principalText, keyboard: .decimalPad)
                LabeledField(title: "Annual rate (%)", text: $rateText, keyboard: .decimalPad)
                LabeledField(title: "Years", text: $yearsText, keyboard: .decimalPad)
                if kind == .compound {
                    LabeledField(title: "Compounds/year", text: $compoundsText, keyboard: .numberPad)
                }
            }

            Section("Result") {
                LabeledContent("Interest", value: Money.string(result.interest))
                LabeledContent("Total",    value: Money.string(result.total))
            }
        }
        .navigationTitle("Interest Calculator")
    }

    private var result: InterestCalculator.Result {
        let p = Double(principalText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let r = Double(rateText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let y = Double(yearsText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let n = Int(compoundsText) ?? 12
        return InterestCalculator.calculate(kind: kind, principal: p, annualRatePercent: r, years: y, compoundsPerYear: n)
    }
}

private struct LabeledField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
    }
}

#Preview {
    NavigationStack { InterestCalculatorView() }
}
