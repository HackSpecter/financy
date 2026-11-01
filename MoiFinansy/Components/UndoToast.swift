import SwiftUI

/// Состояние тоста «Операция сохранена · Отменить».
@Observable
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        var message: String
        var undo: (() -> Void)?

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    static let shared = ToastCenter()

    var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, undo: (() -> Void)? = nil) {
        let toast = Toast(message: message, undo: undo)
        current = toast
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, self?.current?.id == toast.id else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

struct UndoToastView: View {
    var toast: ToastCenter.Toast
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.positive)
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            Spacer(minLength: 8)
            if toast.undo != nil {
                Button("Отменить", action: onUndo)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 16)
    }
}

extension View {
    /// Показывает тост из `ToastCenter` поверх экрана.
    func undoToast(_ center: ToastCenter) -> some View {
        overlay(alignment: .top) {
            if let toast = center.current {
                UndoToastView(toast: toast) {
                    toast.undo?()
                    center.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
        .animation(.spring(duration: 0.4), value: center.current)
    }
}

#Preview {
    UndoToastView(toast: .init(message: "Такси · 20 TJS", undo: {}), onUndo: {})
}
