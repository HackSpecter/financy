import SwiftUI

/// Плавающая стеклянная кнопка «+» над контентом.
struct FloatingAddButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Добавить операцию")
        .padding(.trailing, 20)
        .padding(.bottom, 12)
    }
}

extension View {
    func floatingAddButton(action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            FloatingAddButton(action: action)
        }
    }
}

#Preview {
    Color.clear.floatingAddButton {}
}
