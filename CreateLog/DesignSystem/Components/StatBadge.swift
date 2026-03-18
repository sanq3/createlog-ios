import SwiftUI

struct StatBadge: View {
    let value: String
    let label: String
    var change: String? = nil
    var changePositive: Bool = true

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.clNumber)
                    .foregroundStyle(Color.clTextPrimary)
                    .tabularNumbers()

                Text(label)
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)

                if let change {
                    Text(change)
                        .font(.clCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(changePositive ? Color.clSuccess : Color.clError)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
