import SwiftUI

extension Font {
    static let clLargeTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let clTitle = Font.system(size: 20, weight: .bold, design: .default)
    static let clHeadline = Font.system(size: 14, weight: .semibold, design: .default)
    static let clBody = Font.system(size: 14, weight: .regular, design: .default)
    static let clCaption = Font.system(size: 11, weight: .regular, design: .default)
    static let clNumber = Font.system(size: 24, weight: .heavy, design: .default)
    static let clBigNumber = Font.system(size: 64, weight: .heavy, design: .default)
    static let clTimer = Font.system(size: 48, weight: .heavy, design: .monospaced)
}

extension View {
    func tabularNumbers() -> some View {
        self.monospacedDigit()
    }
}
