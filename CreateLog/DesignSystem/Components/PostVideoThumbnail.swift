import SwiftUI

struct PostVideoThumbnail: View {
    let video: PostVideo

    var body: some View {
        let c = video.placeholderColor
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: c.red, green: c.green, blue: c.blue),
                        Color(red: c.red * 0.6, green: c.green * 0.6, blue: c.blue * 0.6),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(video.aspectRatio, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .circle)
            )
            .overlay(alignment: .bottomTrailing) {
                Text(video.duration)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
                    .padding(10)
            }
    }
}
