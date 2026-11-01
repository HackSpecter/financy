import SwiftUI

/// Курсы валют: ручной ввод и обновление из открытого API (с кешем, работает офлайн).
struct CurrencyRatesView: View {
    @Environment(AppSettings.self) private var settings
    @State private var rates: [String: String] = [:]
    @State private var isLoading = false
    @State private var message: String?
    @State private var autoUpdate = SharedDefaults.store.bool(forKey: "fx.auto")

    var body: some View {
        Form {
            Section {
                ForEach(CurrencyService.supported.filter { $0 != settings.currencyCode }, id: \.self) { currency in
                    HStack {
                        Text("1 \(currency) =")
                        TextField("курс", text: binding(currency))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                        Text(settings.currencyCode).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Курсы к \(settings.currencyCode)")
            } footer: {
                if let date = CurrencyService.lastUpdate {
                    Text("Обновлено \(date.appFormatted("dMMMMHHmm")). Без сети используется сохранённый курс.")
                } else {
                    Text("Курсы введены вручную или приблизительные. Отчёты пересчитываются в \(settings.currencyCode).")
                }
            }
            Section {
                Button {
                    Task { await refresh() }
                } label: {
                    HStack {
                        Label("Обновить из интернета", systemImage: "arrow.clockwise")
                        if isLoading { Spacer(); ProgressView() }
                    }
                }
                .disabled(isLoading)
                Toggle("Обновлять раз в день", isOn: $autoUpdate)
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            } footer: {
                Text("Источник: open.er-api.com (бесплатно, без ключа).")
            }
        }
        .themedBackground()
        .navigationTitle("Курсы валют")
        .onAppear(perform: load)
        .onChange(of: autoUpdate) { SharedDefaults.store.set(autoUpdate, forKey: "fx.auto") }
    }

    private func binding(_ currency: String) -> Binding<String> {
        Binding(
            get: { rates[currency] ?? "" },
            set: { value in
                rates[currency] = value
                if let rate = Money.parse(value), rate > 0 {
                    CurrencyService.setRate(rate, for: currency)
                    WidgetRefresher.reload()
                }
            }
        )
    }

    private func load() {
        for currency in CurrencyService.supported {
            rates[currency] = Money.formatNumber(CurrencyService.rate(for: currency), maxFraction: 4).replacingOccurrences(of: "\u{00A0}", with: "")
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await ExchangeRateFetcher.refresh(base: settings.currencyCode)
            load()
            message = "Курсы обновлены"
        } catch {
            message = "Нет связи — оставлены сохранённые курсы"
        }
    }
}

/// Загрузка курсов из open.er-api.com.
enum ExchangeRateFetcher {
    private struct Response: Decodable {
        var result: String
        var rates: [String: Decimal]
    }

    static func refresh(base: String) async throws {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(base)") else { return }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.result == "success" else { throw URLError(.badServerResponse) }
        for currency in CurrencyService.supported where currency != base {
            // API: сколько валюты за 1 базовую → нам нужно обратное.
            if let perBase = response.rates[currency], perBase > 0 {
                CurrencyService.setRate((1 / perBase).rounded(4), for: currency)
            }
        }
        CurrencyService.lastUpdate = .now
        WidgetRefresher.reload()
    }

    /// Автообновление раз в сутки, если включено.
    static func refreshIfNeeded(base: String) async {
        guard SharedDefaults.store.bool(forKey: "fx.auto") else { return }
        if let last = CurrencyService.lastUpdate, Date.now.timeIntervalSince(last) < 86_400 { return }
        try? await refresh(base: base)
    }
}

#Preview {
    NavigationStack { CurrencyRatesView() }
        .environment(AppSettings.shared)
}
