import SwiftUI
import WatchKit

/// Быстрый расход: цифры → категория.
struct WatchAddExpenseView: View {
    @Environment(WatchStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var choosingCategory = false

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ",", "0", "⌫"]

    var body: some View {
        NavigationStack {
            if choosingCategory, let amount = amount {
                List(store.snapshot.categories) { category in
                    Button {
                        store.addExpense(amount, category: category)
                        WKInterfaceDevice.current().play(.success)
                        dismiss()
                    } label: {
                        Label {
                            Text(category.name)
                        } icon: {
                            Image(systemName: category.symbol).foregroundStyle(Color(hex: category.colorHex))
                        }
                    }
                }
                .navigationTitle(WatchFormat.amount(amount, currency: store.snapshot.currency))
            } else {
                VStack(spacing: 4) {
                    Text(text.isEmpty ? "0" : text)
                        .font(.system(.title2, design: .rounded).bold())
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                        ForEach(0..<4) { row in
                            GridRow {
                                ForEach(0..<3) { column in
                                    let key = keys[row * 3 + column]
                                    Button(key) { press(key) }
                                        .font(.body.weight(.semibold))
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    Button("Далее") { choosingCategory = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.18, green: 0.62, blue: 0.37))
                        .disabled(amount == nil || store.snapshot.categories.isEmpty)
                }
                .navigationTitle("Расход")
            }
        }
    }

    private var amount: Decimal? {
        Decimal(string: text.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")).flatMap { $0 > 0 ? $0 : nil }
    }

    private func press(_ key: String) {
        WKInterfaceDevice.current().play(.click)
        switch key {
        case "⌫": if !text.isEmpty { text.removeLast() }
        case ",": if !text.contains(",") { text += text.isEmpty ? "0," : "," }
        default:
            if let comma = text.firstIndex(of: ","), text[comma...].count > 2 { return }
            if text.count < 8 { text += key }
        }
    }
}
