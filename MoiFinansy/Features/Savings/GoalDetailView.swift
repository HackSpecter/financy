import SwiftData
import SwiftUI

struct GoalDetailView: View {
    @Bindable var goal: SavingsGoal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var customAmount = ""
    /// nil — «Уже отложено (не списывать)».
    @State private var sourceAccount: Account?
    @Query(sort: \Account.order) private var accounts: [Account]
    @State private var editing = false
    @State private var added = 0

    var body: some View {
        let progress = goal.progress
        List {
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(Color(hex: goal.colorHex).opacity(0.2), lineWidth: 14)
                        Circle().trim(from: 0, to: progress.fraction)
                            .stroke(Color(hex: goal.colorHex).gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring, value: progress.fraction)
                        VStack(spacing: 2) {
                            Image(systemName: goal.symbol).font(.title).foregroundStyle(Color(hex: goal.colorHex))
                            Text("\(Int(progress.fraction * 100))%").font(.title2.bold()).fontDesign(.rounded)
                        }
                    }
                    .frame(width: 160, height: 160)
                    MoneyText(amount: progress.saved, font: .title.bold())
                    Text("из \(Money.format(goal.targetAmount, currency: settings.currencyCode))").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Расчёт") {
                if progress.isReached {
                    Label("Цель достигнута!", systemImage: "party.popper.fill").foregroundStyle(Theme.positive)
                } else {
                    LabeledContent("Осталось", value: Money.format(progress.remaining, currency: settings.currencyCode))
                    if let deadline = goal.deadline {
                        LabeledContent("Срок", value: deadline.appFormatted("dMMMMyyyy"))
                        if let perMonth = progress.perMonth { LabeledContent("Нужно в месяц", value: Money.format(perMonth, currency: settings.currencyCode)) }
                        if let perDay = progress.perDay { LabeledContent("Или в день", value: Money.format(perDay, currency: settings.currencyCode)) }
                    }
                    LabeledContent("Ваш темп", value: progress.monthlyPace > 0 ? "\(Money.format(progress.monthlyPace.rounded(0), currency: settings.currencyCode)) / мес." : "нет пополнений")
                    if let forecast = progress.forecastDate {
                        LabeledContent("Прогноз", value: forecast.appFormatted("LLLLyyyy"))
                    }
                    if let onTrack = progress.isOnTrack {
                        Label(onTrack ? "Успеваете к сроку" : "При текущем темпе не успеваете — увеличьте пополнения",
                              systemImage: onTrack ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(onTrack ? Theme.positive : Theme.caution)
                    }
                }
            }

            Section {
                HStack {
                    ForEach(quickAmounts(progress), id: \.self) { amount in
                        Button(Money.formatNumber(amount)) { contribute(amount) }
                            .buttonStyle(.glass)
                            .frame(maxWidth: .infinity)
                    }
                }
                HStack {
                    TextField("Другая сумма", text: $customAmount).keyboardType(.decimalPad)
                    Button("Пополнить") {
                        if let amount = Money.parse(customAmount), amount > 0 { contribute(amount); customAmount = "" }
                    }
                    .disabled(Money.parse(customAmount) == nil)
                }
                Picker("Откуда деньги", selection: $sourceAccount) {
                    Text("Уже отложено (не списывать)").tag(Account?.none)
                    ForEach(accounts.filter { !$0.archived && !$0.isSavings }) { account in
                        Text("Со счёта «\(account.name)»").tag(Optional(account))
                    }
                }
            } header: {
                Text("Пополнить одним тапом")
            } footer: {
                Text("«Уже отложено» — деньги лежат отдельно, наличные и карта не меняются. «Со счёта» — сумма переводится с выбранного счёта в копилку.")
            }

            Section("История") {
                ForEach((goal.contributions ?? []).sorted { $0.date > $1.date }) { contribution in
                    HStack {
                        Text(contribution.date.appFormatted("dMMMyyyy"))
                        Spacer()
                        Text("+" + Money.format(contribution.amount, currency: settings.currencyCode)).foregroundStyle(Theme.positive).monospacedDigit()
                    }
                }
                .onDelete { offsets in
                    let sorted = (goal.contributions ?? []).sorted { $0.date > $1.date }
                    offsets.map { sorted[$0] }.forEach(context.delete)
                    try? context.save()
                }
            }
        }
        .themedBackground()
        .navigationTitle(goal.name)
        .toolbar {
            Button("Изменить", systemImage: "pencil") { editing = true }
        }
        .sheet(isPresented: $editing) { GoalEditor(goal: goal) }
        .sensoryFeedback(.success, trigger: added)
    }

    private func quickAmounts(_ progress: GoalCalculator.Progress) -> [Decimal] {
        var amounts: [Decimal] = [100, 500]
        if let perMonth = progress.perMonth, perMonth > 0, !amounts.contains(perMonth) { amounts.append(perMonth) } else { amounts.append(1000) }
        return amounts
    }

    private func contribute(_ amount: Decimal) {
        SavingsService.contribute(amount, to: goal, from: sourceAccount, in: context)
        added += 1
    }
}

struct GoalEditor: View {
    var goal: SavingsGoal?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var name = ""
    @State private var targetText = ""
    @State private var hasDeadline = true
    @State private var deadline = AppCalendar.calendar.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var symbol = "star.fill"
    @State private var colorHex = "#34C759"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        CategoryIcon(symbol: symbol, colorHex: colorHex, size: 44)
                        TextField("Название, напр. «Телефон»", text: $name).font(.title3)
                    }
                    HStack {
                        TextField("Сумма цели", text: $targetText).keyboardType(.decimalPad)
                        Text(settings.currencyCode).foregroundStyle(.secondary)
                    }
                    Toggle("Срок", isOn: $hasDeadline.animation())
                    if hasDeadline {
                        DatePicker("К дате", selection: $deadline, in: Date.now..., displayedComponents: .date)
                    }
                }
                Section("Иконка") { SymbolColorPicker(symbol: $symbol, colorHex: $colorHex) }
                if let goal {
                    Button("В архив", systemImage: "archivebox", role: .destructive) {
                        goal.isArchived = true
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .themedBackground()
            .navigationTitle(goal == nil ? "Новая цель" : "Цель")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save)
                        .disabled(name.isEmpty || Money.parse(targetText) == nil)
                }
            }
            .onAppear {
                guard let goal else { return }
                name = goal.name
                targetText = Money.formatNumber(goal.targetAmount).replacingOccurrences(of: "\u{00A0}", with: "")
                hasDeadline = goal.deadline != nil
                deadline = goal.deadline ?? deadline
                symbol = goal.symbol
                colorHex = goal.colorHex
            }
        }
    }

    private func save() {
        guard let target = Money.parse(targetText), target > 0 else { return }
        let item = goal ?? SavingsGoal(name: name, targetAmount: target, deadline: nil, symbol: symbol, colorHex: colorHex)
        item.name = name
        item.targetAmount = target
        item.deadline = hasDeadline ? deadline : nil
        item.symbol = symbol
        item.colorHex = colorHex
        if goal == nil { context.insert(item) }
        try? context.save()
        WidgetRefresher.reload()
        dismiss()
    }
}
