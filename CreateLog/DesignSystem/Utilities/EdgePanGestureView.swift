import SwiftUI

// MARK: - iOS 18+ UIGestureRecognizerRepresentable

/// UIScreenEdgePanGestureRecognizer をSwiftUIジェスチャーとして統合。
/// .gesture() / .highPriorityGesture() で付けることで、
/// SwiftUIがScrollViewのパンジェスチャーとの優先順位を調停する。
struct EdgePanGesture: UIGestureRecognizerRepresentable {
    @Binding var dragOffset: CGFloat
    var isEnabled: Bool
    var onEnd: (Bool) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIScreenEdgePanGestureRecognizer {
        let gesture = UIScreenEdgePanGestureRecognizer()
        gesture.edges = .left
        gesture.isEnabled = isEnabled
        return gesture
    }

    func updateUIGestureRecognizer(_ recognizer: UIScreenEdgePanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UIScreenEdgePanGestureRecognizer,
        context: Context
    ) {
        let translation = recognizer.translation(in: recognizer.view)
        let velocity = recognizer.velocity(in: recognizer.view)

        switch recognizer.state {
        case .changed:
            let menuWidth = (recognizer.view?.bounds.width ?? 390) * 0.82
            dragOffset = max(0, min(translation.x, menuWidth))
        case .ended, .cancelled:
            let menuWidth = (recognizer.view?.bounds.width ?? 390) * 0.82
            let shouldOpen = translation.x > menuWidth * 0.5 || velocity.x > 500
            onEnd(shouldOpen)
        default:
            break
        }
    }
}
