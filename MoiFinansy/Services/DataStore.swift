import Foundation
import SwiftData

enum DataStore {
    static let cloudContainerID = "iCloud.tj.khalid.hisob"

    static let schema = Schema([
        Transaction.self,
        Category.self,
        Account.self,
        Budget.self,
        RecurringRule.self,
        Template.self,
        PlannerItem.self,
        BankCard.self,
        BankSMSRule.self,
        MerchantRule.self,
        SMSImportLog.self,
        Attachment.self,
        SavingsGoal.self,
        GoalContribution.self,
        Debt.self,
        DebtPayment.self,
        Envelope.self,
        MonthClosure.self,
    ])

    /// Общий контейнер приложения, виджетов и интентов.
    /// Виджеты читают тот же файл без зеркалирования в CloudKit — синхронизирует только приложение.
    #if APP_EXTENSION
    static let shared: ModelContainer = makeContainer(cloudSync: false)
    #else
    static let shared: ModelContainer = makeContainer(cloudSync: SharedDefaults.iCloudSyncEnabled)
    #endif

    static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.appGroup)
            ?? URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "MoiFinansy.store")
    }

    static func makeContainer(inMemory: Bool = false, cloudSync: Bool = false) -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: configuration)
        }
        if cloudSync {
            let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .private(cloudContainerID))
            if let container = try? ModelContainer(for: schema, configurations: configuration) {
                return container
            }
        }
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Не удалось открыть хранилище: \(error)")
        }
    }
}
