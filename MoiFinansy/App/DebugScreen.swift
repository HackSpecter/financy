#if DEBUG
import SwiftUI

/// Экраны, которые можно открыть аргументом запуска `-screen <name>` (только DEBUG, для скриншотов).
enum DebugScreen: String, Identifiable {
    case ayatVariants, ayatCases, ayatHowTo, ayat, ayatSettings, ayatPreview, ayatDetail, savings, debts, networth, cashflow, subscriptions, envelopes, months, weekly, sms, guide, trainer, rates, settings

    var id: String { rawValue }

    @ViewBuilder
    var view: some View {
        switch self {
        case .ayatVariants: AyahVariantsGallery()
        case .ayatCases: AyahCasesGallery()
        case .ayatHowTo: HowToAddAyahView()
        case .ayat: AyatHomeView()
        case .ayatSettings: AyahSettingsView()
        case .ayatPreview: LockScreenPreviewView()
        case .ayatDetail: AyahDetailView(index: QuranStore.index(of: AyahRef(sura: 94, ayah: 5)) ?? 0)
        case .savings: SavingsView()
        case .debts: DebtsView()
        case .networth: NetWorthView()
        case .cashflow: CashFlowCalendarView()
        case .subscriptions: SubscriptionsView()
        case .envelopes: EnvelopesView()
        case .months: MonthClosuresView()
        case .weekly: WeeklyReviewView()
        case .sms: SMSSettingsView()
        case .guide: SMSSetupGuideView()
        case .trainer: ParserTrainerView()
        case .rates: CurrencyRatesView()
        case .settings: SettingsView()
        }
    }
}
#endif
