import SwiftData
import SwiftUI

/// Сетка категорий: тап сохраняет операцию.
struct CategoryGrid: View {
    var categories: [Category]
    var highlightedID: UUID?
    var onSelect: (Category) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(categories) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        VStack(spacing: 4) {
                            CategoryIcon(category: category, size: 44)
                                .overlay {
                                    if category.id == highlightedID {
                                        Circle().strokeBorder(.tint, lineWidth: 3).padding(-4)
                                    }
                                }
                            Text(category.name)
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .top)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Сохранить в категорию \(category.name)")
                }
            }
            .padding(.vertical, 6)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 250)
        .animation(.snappy, value: highlightedID)
    }
}

#Preview {
    let container = DemoData.previewContainer
    let categories = try! container.mainContext.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.order)]))
    return CategoryGrid(categories: categories.filter { $0.kind == .expense }, highlightedID: categories.first?.id) { _ in }.padding()
}
