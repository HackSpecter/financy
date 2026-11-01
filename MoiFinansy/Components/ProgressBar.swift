import SwiftUI

/// Горизонтальный прогресс с опциональной меткой «сегодня».
struct ProgressBar: View {
    var value: Double
    var tint: Color
    var marker: Double? = nil
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(height, width * min(max(value, 0), 1)))
                if let marker {
                    Capsule()
                        .fill(.primary.opacity(0.6))
                        .frame(width: 2, height: height + 6)
                        .offset(x: width * min(max(marker, 0), 1) - 1)
                }
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.5), value: value)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(value * 100)) процентов"))
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressBar(value: 0.4, tint: Theme.positive, marker: 0.55)
        ProgressBar(value: 0.92, tint: Theme.caution)
        ProgressBar(value: 1.2, tint: Theme.negative)
    }
    .padding()
}
