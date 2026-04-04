import SwiftUI

struct PostCodeBlock: View {
    let code: PostCode
    var maxLines: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(code.language)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.clAccent)

                Spacer()

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.clTextTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Text(code.code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.clTextSecondary)
                .lineLimit(maxLines)
                .padding(12)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
