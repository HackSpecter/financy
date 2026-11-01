import SwiftData
import SwiftUI

/// Выбор счетов для перевода.
struct TransferAccountsView: View {
    @Bindable var model: QuickAddModel
    var accounts: [Account]

    var body: some View {
        VStack(spacing: 10) {
            row(title: "Откуда", selection: $model.account)
            Button {
                swap(&model.account, &model.toAccount)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Поменять счета местами")
            row(title: "Куда", selection: $model.toAccount)
        }
        .card()
    }

    private func row(title: String, selection: Binding<Account?>) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(accounts) { account in
                    Label(account.name, systemImage: account.symbol).tag(Optional(account))
                }
            }
            .pickerStyle(.menu)
        }
    }
}

#Preview {
    let container = DemoData.previewContainer
    let accounts = try! container.mainContext.fetch(FetchDescriptor<Account>())
    let model = QuickAddModel(type: .transfer)
    model.prepare(accounts: accounts)
    return TransferAccountsView(model: model, accounts: accounts).padding()
}
