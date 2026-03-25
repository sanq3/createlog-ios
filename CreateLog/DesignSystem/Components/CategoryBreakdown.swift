import SwiftUI

struct CategoryBreakdown: View {
    let categories: [CategoryItem]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("カテゴリ別")
                    .font(.clHeadline)
                    .foregroundStyle(Color.clTextSecondary)

                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.clAccent.opacity(1.0 - Double(index) * 0.25))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(category.name)
                                .font(.clHeadline)
                                .foregroundStyle(Color.clTextPrimary)
                            Text(String(format: "%.0fh %02dm", floor(category.hours), Int((category.hours.truncatingRemainder(dividingBy: 1)) * 60)))
                                .font(.clCaption)
                                .foregroundStyle(Color.clTextTertiary)
                        }

                        Spacer()

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.clSurfaceLow)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.clAccent.opacity(1.0 - Double(index) * 0.25),
                                                    Color.clAccent.opacity(0.6 - Double(index) * 0.15)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * category.percentage / 100)
                                }
                        }
                        .frame(width: 100, height: 6)

                        Text("\(Int(category.percentage))%")
                            .font(.clCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.clTextSecondary)
                            .frame(width: 36, alignment: .trailing)
                            .tabularNumbers()
                    }

                    if index < categories.count - 1 {
                        Divider()
                            .overlay(Color.clBorder)
                    }
                }
            }
        }
    }
}
