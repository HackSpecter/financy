import SwiftUI

struct ForecastCard: View {
    var forecast: BudgetCalculator.Forecast
    var now: Date
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Прогноз")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var text: String {
        switch forecast {
        case .leftover(let amount):
            "При текущем темпе к концу месяца останется ~\(Money.format(amount, currency: settings.currencyCode))"
        case .runsOut(let day):
            "При текущем темпе денег хватит до \(day) числа"
        case .unknown:
            "Добавьте пару расходов — и появится прогноз"
        }
    }

    private var symbol: String {
        switch forecast {
        case .leftover: "chart.line.uptrend.xyaxis"
        case .runsOut: "exclamationmark.triangle.fill"
        case .unknown: "sparkles"
        }
    }

    private var color: Color {
        switch forecast {
        case .leftover: Theme.positive
        case .runsOut: Theme.caution
        case .unknown: .blue
        }
    }
}

#Preview {
    VStack {
        ForecastCard(forecast: .leftover(3200), now: .now)
        ForecastCard(forecast: .runsOut(day: 24), now: .now)
    }
    .padding()
    .environment(AppSettings.shared)
}
