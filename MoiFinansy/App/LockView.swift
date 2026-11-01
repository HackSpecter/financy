import SwiftUI

/// Экран блокировки: скрывает данные до проверки Face ID.
struct LockView: View {
    var onUnlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)
                Text("Khalid Finance")
                    .font(.title.bold())
                Button(action: onUnlock) {
                    Label("Разблокировать", systemImage: "faceid")
                        .font(.headline)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    LockView {}
}
