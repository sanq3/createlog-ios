import SwiftUI

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
        }
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}
