import SwiftUI

/// Мягкая геймификация: серия дней в пределах лимита.
struct StreakBadge: View {
    var current: Int
    var best: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: current > 0 ? "flame.fill" : "flame")
                .font(.title3)
                .foregroundStyle(current > 0 ? AnyShapeStyle(LinearGradient(colors: [Theme.caution, Theme.negative], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(.secondary))
                .symbolEffect(.bounce, value: current)
            VStack(alignment: .leading, spacing: 1) {
                Text(current > 0 ? "\(current) \(daysWord(current)) подряд в пределах лимита" : "Начните серию — уложитесь в лимит сегодня")
                    .font(.subheadline.weight(.semibold))
                if best > 0 {
                    Text(current >= best && current > 0 ? "Это ваш рекорд!" : "Рекорд: \(best) \(daysWord(best))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func daysWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1, mod100 != 11 { return "день" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "дня" }
        return "дней"
    }
}

#Preview {
    VStack {
        StreakBadge(current: 5, best: 12)
        StreakBadge(current: 0, best: 3)
    }
    .cardPreview()
}
