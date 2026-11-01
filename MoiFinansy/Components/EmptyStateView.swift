import SwiftUI

/// Пустое состояние: иконка SF Symbols и подсказка, что делать.
struct EmptyStateView: View {
    var title: String
    var symbol: String
    var message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
                .symbolRenderingMode(.hierarchical)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glassProminent)
            }
        }
    }
}

#Preview {
    EmptyStateView(title: "Пока нет операций", symbol: "tray", message: "Нажмите «+», чтобы добавить первый расход", actionTitle: "Добавить") {}
}
