import SwiftUI

/// Выбор иконки SF Symbols и цвета для категорий и счетов.
struct SymbolColorPicker: View {
    @Binding var symbol: String
    @Binding var colorHex: String

    static let symbols = [
        "cart.fill", "fork.knife", "cup.and.saucer.fill", "car.fill", "bus.fill", "fuelpump.fill",
        "wifi", "iphone", "house.fill", "bolt.fill", "drop.fill", "tshirt.fill",
        "cross.case.fill", "pills.fill", "gamecontroller.fill", "film.fill", "gift.fill", "heart.fill",
        "figure.2.and.child.holdinghands", "graduationcap.fill", "book.fill", "pawprint.fill", "airplane", "dumbbell.fill",
        "scissors", "wrench.and.screwdriver.fill", "creditcard.fill", "banknote.fill", "briefcase.fill", "building.columns.fill",
        "chart.line.uptrend.xyaxis", "arrow.uturn.backward.circle.fill", "star.fill", "bag.fill", "basket.fill", "ellipsis.circle.fill",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Color.palette, id: \.self) { hex in
                        Button {
                            colorHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Цвет \(hex)")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(Self.symbols, id: \.self) { name in
                    Button {
                        symbol = name
                    } label: {
                        Image(systemName: name)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(name == symbol ? .white : .primary)
                            .background(name == symbol ? AnyShapeStyle(Color(hex: colorHex).gradient) : AnyShapeStyle(.quaternary), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(name)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    @Previewable @State var symbol = "car.fill"
    @Previewable @State var color = "#FFCC00"
    SymbolColorPicker(symbol: $symbol, colorHex: $color).padding()
}
