import SwiftUI

/// Проверка вёрстки виджета экрана блокировки для особых случаев режима «по времени».
struct AyahCasesGallery: View {
    private let times: [(Int, Int)] = [(13, 39), (2, 15), (0, 5), (13, 50), (1, 0), (23, 59)]

    var body: some View {
        let settings = AyahSettings()
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(cases(settings), id: \.label) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        AyahLockView(text: item.pick.text, title: item.pick.title, style: settings.style, fontScale: item.pick.fontScale)
                            .frame(width: AyahLayout.lockBox.width, height: AyahLayout.lockBox.height)
                            .foregroundStyle(.white.opacity(0.92))
                            .padding(6)
                            .background(Color(red: 0.12, green: 0.14, blue: 0.24), in: .rect(cornerRadius: 12))
                    }
                }
            }
            .padding(12)
        }
        .navigationTitle("Аят по времени")
        .navigationBarTitleDisplayMode(.inline)
    }

    static func points(_ pick: AyahPick, _ settings: AyahSettings) -> String {
        Money.formatNumber(Decimal(Double(settings.style.size.lockPointSize * pick.fontScale)), maxFraction: 1)
    }

    private func cases(_ settings: AyahSettings) -> [(label: String, pick: AyahPick)] {
        var result: [(String, AyahPick)] = []
        let calendar = AyahPicker.deviceCalendar
        for (hour, minute) in times where hour < 24 {
            var components = calendar.dateComponents([.year, .month, .day], from: .now)
            components.hour = hour
            components.minute = minute
            guard let date = calendar.date(from: components),
                  let pick = AyahPicker.byTime(date, settings: settings, surface: .lock(AyahLayout.lockBox), calendar: calendar) else { continue }
            let note = pick.isTruncated ? " · «…»" : pick.fontScale < 1 ? " · \(Self.points(pick, settings)) pt" : ""
            result.append((String(format: "%02d:%02d", hour, minute) + note, pick))
        }
        let lengths = (0..<QuranText.ayahCount).map { ($0, QuranStore.translation(settings.translation, at: $0).count) }
        if let shortest = lengths.min(by: { $0.1 < $1.1 })?.0,
           let pick = AyahPicker.fitted(shortest...shortest, settings: settings, surface: .lock(AyahLayout.lockBox)) {
            result.append(("Самый короткий", pick))
        }
        if let longest = lengths.max(by: { $0.1 < $1.1 })?.0,
           let pick = AyahPicker.fitted(longest...longest, settings: settings, surface: .lock(AyahLayout.lockBox)) ?? AyahPicker.truncated(longest, settings: settings, surface: .lock(AyahLayout.lockBox)) {
            result.append(("Самый длинный · «…»", pick))
        }
        var short = settings
        short.overflow = .shortAyahSameSura
        let calendar2 = AyahPicker.deviceCalendar
        var parts = calendar2.dateComponents([.year, .month, .day], from: .now)
        parts.hour = 2; parts.minute = 15
        if let date = calendar2.date(from: parts), let pick = AyahPicker.byTime(date, settings: short, surface: .lock(AyahLayout.lockBox), calendar: calendar2) {
            result.append(("02:15 · короткий из суры", pick))
        }
        return result
    }
}

#Preview {
    NavigationStack { AyahCasesGallery() }
}
