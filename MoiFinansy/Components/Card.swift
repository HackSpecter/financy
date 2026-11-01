import SwiftUI

/// Карточка контента в стиле Wallet/Health — белая на системном фоне.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// Заголовок карточки с необязательной ссылкой справа.
struct CardHeader<Trailing: View>: View {
    var title: String
    var symbol: String
    var tint: Color = .secondary
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Spacer()
            trailing
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(title: String, symbol: String, tint: Color = .secondary) {
        self.init(title: title, symbol: symbol, tint: tint) { EmptyView() }
    }
}

#Preview {
    VStack {
        VStack(alignment: .leading) {
            CardHeader(title: "Баланс", symbol: "wallet.bifold.fill")
            Text("51 054 TJS").font(.title.bold())
        }
        .card()
    }
    .padding()
    .background { AmbientBackground() }
}
