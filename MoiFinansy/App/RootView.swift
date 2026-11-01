import SwiftData
import SwiftUI

/// Онбординг, блокировка Face ID и основная навигация.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @State private var isLocked = AppSettings.shared.faceIDEnabled
    @State private var isAuthenticating = false
    @State private var lastMaintenance = Date.distantPast

    var body: some View {
        Group {
            if settings.hasOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .overlay {
            if isLocked {
                LockView { unlock() }
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(AppAppearance(rawValue: settings.appearanceRaw)?.colorScheme)
        .tint(Theme.accent)
        .animation(.easeOut(duration: 0.2), value: isLocked)
        .animation(.smooth, value: settings.hasOnboarded)
        .task { if scenePhase == .active { activate() } }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                activate()
            case .background:
                if settings.faceIDEnabled { isLocked = true }
                settings.hideAmounts()
            default:
                break
            }
        }
    }

    /// Открытие приложения: сначала Face ID, фоновая работа — только после разблокировки.
    private func activate() {
        router.consumePendingActions()
        if isLocked {
            unlock()
        } else {
            scheduleMaintenance()
        }
    }

    private func unlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            let success = await BiometricService.authenticate()
            isAuthenticating = false
            guard success else { return }
            isLocked = false
            scheduleMaintenance()
        }
    }

    /// Регулярные платежи, напоминания, часы и т. п. — не чаще раза в 10 секунд и не блокируя экран.
    private func scheduleMaintenance() {
        guard Date.now.timeIntervalSince(lastMaintenance) > 10 else { return }
        lastMaintenance = .now
        Task {
            await Task.yield()
            RecurringService.processDue(in: context)
            SMSImportService.purgeOldLogs(in: context)
            SubscriptionReminders.reschedule(in: context)
            MonthCloseService.closePastMonthIfNeeded(in: context)
            MonthCloseService.scheduleLastDayReminder()
            MotivationService.scheduleWeeklyReview()
            WatchSync.shared.schedulePush()
            AyahNotifications.reschedule(AyahSettings.current)
            await AyahWidgetsState.refresh()
            LiveActivityService.refresh()
            // Курсы валют — из сети, без ожидания.
            let currency = settings.currencyCode
            Task { await ExchangeRateFetcher.refreshIfNeeded(base: currency) }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
        .environment(AppRouter.shared)
        .environment(ToastCenter.shared)
}
