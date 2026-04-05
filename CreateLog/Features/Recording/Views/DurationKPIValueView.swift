import SwiftUI

struct DurationKPIValueView: View {
    let minutes: Int
    let referenceMinutes: Int?

    init(minutes: Int, referenceMinutes: Int? = nil) {
        self.minutes = minutes
        self.referenceMinutes = referenceMinutes
    }

    private var parts: DurationFormatter.KPIDisplayParts {
        DurationFormatter.kpiDisplayParts(minutes: minutes, referenceMinutes: referenceMinutes)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(parts.primaryValue)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.clTextPrimary)
            Text(parts.primaryUnit)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.clTextTertiary)

            if let secondaryValue = parts.secondaryValue,
               let secondaryUnit = parts.secondaryUnit {
                Text(secondaryValue)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.clTextPrimary)
                Text(secondaryUnit)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.clTextTertiary)
            }
        }
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}
