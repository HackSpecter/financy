import SwiftUI

/// Состояние ввода суммы с цифровой клавиатуры.
struct AmountInput: Equatable {
    private(set) var text = ""

    var decimal: Decimal? { Money.parse(text).flatMap { $0 > 0 ? $0 : nil } }

    /// Отображение с разделением разрядов: «1 250,5».
    var display: String {
        guard !text.isEmpty else { return "0" }
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        let integer = Decimal(string: String(parts[0])) ?? 0
        var result = Money.formatNumber(integer, maxFraction: 0)
        if parts.count > 1 { result += "," + parts[1] }
        return result
    }

    mutating func press(_ key: AmountKeypad.Key) {
        switch key {
        case .digit(let digit):
            let parts = text.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count > 1, parts[1].count >= 2 { return }
            if parts.count == 1, parts[0].count >= 9 { return }
            if text == "0" { text = "" }
            text.append(String(digit))
        case .comma:
            guard !text.contains(",") else { return }
            text = text.isEmpty ? "0," : text + ","
        case .delete:
            if !text.isEmpty { text.removeLast() }
        }
    }

    mutating func set(_ value: Decimal) {
        text = Money.formatNumber(value).replacingOccurrences(of: "\u{00A0}", with: "")
    }

    mutating func clear() { text = "" }
}

/// Большая цифровая клавиатура для ввода суммы.
struct AmountKeypad: View {
    enum Key: Hashable {
        case digit(Int), comma, delete
    }

    var onKey: (Key) -> Void
    @State private var taps = 0

    private let rows: [[Key]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.comma, .digit(0), .delete],
    ]

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button {
                            taps += 1
                            onKey(key)
                        } label: {
                            label(for: key)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .contentShape(.rect)
                        }
                        .buttonStyle(KeypadButtonStyle())
                        .accessibilityLabel(accessibilityLabel(for: key))
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: taps)
    }

    @ViewBuilder
    private func label(for key: Key) -> some View {
        switch key {
        case .digit(let digit):
            Text("\(digit)").font(.title.weight(.medium)).fontDesign(.rounded)
        case .comma:
            Text(",").font(.title.weight(.medium)).fontDesign(.rounded)
        case .delete:
            Image(systemName: "delete.left").font(.title2)
        }
    }

    private func accessibilityLabel(for key: Key) -> String {
        switch key {
        case .digit(let digit): "\(digit)"
        case .comma: "Запятая"
        case .delete: "Стереть"
        }
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                configuration.isPressed ? AnyShapeStyle(Theme.hairline) : AnyShapeStyle(Theme.fill),
                in: .rect(cornerRadius: 14, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    @Previewable @State var input = AmountInput()
    VStack {
        Text(input.display).font(.largeTitle)
        AmountKeypad { input.press($0) }
    }
    .padding()
}
