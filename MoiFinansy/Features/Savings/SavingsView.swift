import SwiftData
import SwiftUI

/// Накопления: копилка, «заплати себе сначала», округления, цели.
struct SavingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.order) private var accounts: [Account]
    @Query(filter: #Predicate<SavingsGoal> { !$0.isArchived }, sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var percent = SavingsService.payYourselfPercent
    @State private var roundUpEnabled = SavingsService.roundUpEnabled
    @State private var editingGoal: SavingsGoal?
    @State private var isAddingGoal = false
    @State private var transferred = 0

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("В копилке").font(.subheadline).foregroundStyle(.secondary)
                    MoneyText(amount: savingsAccounts.sum(\.balanceInBase), font: .largeTitle.bold())
                    Text("Цели: \(Money.format(goals.sum(\.saved), currency: settings.currencyCode)) из \(Money.format(goals.sum(\.targetAmount), currency: settings.currencyCode))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Stepper(value: $percent, in: 0...50, step: 5) {
                    LabeledContent("Откладывать с зарплаты", value: percent == 0 ? "выкл." : "\(percent)%")
                }
                if percent > 0 {
                    Text("С зарплаты \(Money.format(salaryAmount, currency: settings.currencyCode)) в копилку уйдёт \(Money.format(SavingsCalculator.payYourselfFirst(income: salaryAmount, percent: percent), currency: settings.currencyCode)). Дневной лимит считается уже без этих денег.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Заплати себе сначала")
            }

            Section {
                Toggle("Округлять траты до 10 \(settings.currencyCode)", isOn: $roundUpEnabled)
                if roundUpEnabled {
                    let roundUps = SavingsService.roundUps(in: context)
                    let available = max(roundUps.total - roundUps.transferred, 0)
                    LabeledContent("Набежало за месяц", value: Money.format(roundUps.total, currency: settings.currencyCode))
                    if available > 0, let account = TransactionService.lastAccount(in: context) {
                        Button("Перевести \(Money.format(available, currency: settings.currencyCode)) в копилку", systemImage: "arrow.down.to.line") {
                            SavingsService.transferRoundUps(available, from: account, in: context)
                            transferred += 1
                        }
                    }
                }
            } header: {
                Text("Округления")
            } footer: {
                Text("Трата 45 → 50: разница 5 \(settings.currencyCode) копится виртуально, переводите её в копилку одной кнопкой.")
            }

            Section("Цели") {
                if goals.isEmpty {
                    Text("Добавьте цель — например, «Телефон 6 000 к марту».").foregroundStyle(.secondary)
                }
                ForEach(goals) { goal in
                    NavigationLink { GoalDetailView(goal: goal) } label: { GoalRow(goal: goal) }
                }
                Button("Новая цель", systemImage: "plus.circle.fill") { isAddingGoal = true }
            }
        }
        .themedBackground()
        .navigationTitle("Накопления")
        .onChange(of: percent) { SavingsService.payYourselfPercent = percent; WidgetRefresher.reload() }
        .onChange(of: roundUpEnabled) { SavingsService.roundUpEnabled = roundUpEnabled }
        .sheet(isPresented: $isAddingGoal) { GoalEditor(goal: nil) }
        .sensoryFeedback(.success, trigger: transferred)
    }

    private var savingsAccounts: [Account] { accounts.filter { $0.isSavings && !$0.archived } }

    private var salaryAmount: Decimal {
        transactions.first { $0.type == .income && $0.category?.name == "Зарплата" }?.amount ?? 25_000
    }
}

struct GoalRow: View {
    var goal: SavingsGoal
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let progress = goal.progress
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color(hex: goal.colorHex).opacity(0.2), lineWidth: 5)
                Circle().trim(from: 0, to: progress.fraction)
                    .stroke(Color(hex: goal.colorHex), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: goal.symbol).foregroundStyle(Color(hex: goal.colorHex))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name).font(.body.weight(.medium))
                Text("\(Money.format(progress.saved, currency: settings.currencyCode)) из \(Money.format(goal.targetAmount, currency: settings.currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            if progress.isReached {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.positive)
            } else if let onTrack = progress.isOnTrack {
                Image(systemName: onTrack ? "hare.fill" : "tortoise.fill").foregroundStyle(onTrack ? Theme.positive : Theme.caution)
                    .accessibilityLabel(onTrack ? "Успеваете" : "Не успеваете")
            }
        }
    }
}

#Preview {
    NavigationStack { SavingsView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
