import SwiftUI
import WidgetKit

@main
struct MoiFinansyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AyahLockWidget()
        AyahTitleWidget()
        AyahHomeWidget()
        AllowanceWidget()
        MonthWidget()
        TasksWidget()
        GoalsWidget()
        DebtsWidget()
        SubscriptionsWidget()
        NetWorthWidget()
        QuickAddControl()
        HisobLiveActivity()
    }
}
