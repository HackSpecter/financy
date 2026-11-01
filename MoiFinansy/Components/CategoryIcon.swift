import SwiftUI

struct CategoryIcon: View {
    var symbol: String
    var colorHex: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: colorHex).gradient, in: .circle)
            .accessibilityHidden(true)
    }
}

extension CategoryIcon {
    init(category: Category?, size: CGFloat = 40) {
        self.init(symbol: category?.symbol ?? "questionmark", colorHex: category?.colorHex ?? "#8E8E93", size: size)
    }

    init(transaction: Transaction, size: CGFloat = 40) {
        if transaction.type == .transfer {
            self.init(symbol: "arrow.left.arrow.right", colorHex: "#5856D6", size: size)
        } else if transaction.type == .adjustment {
            self.init(symbol: "plusminus", colorHex: "#8E8E93", size: size)
        } else {
            self.init(category: transaction.category, size: size)
        }
    }
}

#Preview {
    HStack {
        CategoryIcon(symbol: "car.fill", colorHex: "#FFCC00")
        CategoryIcon(symbol: "fork.knife", colorHex: "#FF9500", size: 56)
    }
}
