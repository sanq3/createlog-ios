import SwiftUI

struct EdgePanGesture: UIGestureRecognizerRepresentable {
    @Binding var dragOffset: CGFloat
    var isEnabled: Bool
    var onEnd: (Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer()
        gesture.maximumNumberOfTouches = 1
        gesture.delegate = context.coordinator
        gesture.isEnabled = isEnabled
        return gesture
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.parent = self
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UIPanGestureRecognizer,
        context: Context
    ) {
        guard isEnabled else { return }

        let translation = recognizer.translation(in: recognizer.view)
        let velocity = recognizer.velocity(in: recognizer.view)
        let menuWidth = (recognizer.view?.bounds.width ?? 390) * 0.82

        switch recognizer.state {
        case .changed:
            guard translation.x > 0 else {
                dragOffset = 0
                return
            }
            dragOffset = max(0, min(translation.x, menuWidth))
        case .ended, .cancelled, .failed:
            let shouldOpen = translation.x > menuWidth * 0.5 || velocity.x > 500
            onEnd(shouldOpen)
        default:
            break
        }
    }
}

extension EdgePanGesture {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: EdgePanGesture

        init(parent: EdgePanGesture) {
            self.parent = parent
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard
                parent.isEnabled,
                let panGesture = gestureRecognizer as? UIPanGestureRecognizer
            else {
                return false
            }

            let velocity = panGesture.velocity(in: panGesture.view)
            guard velocity.x > 0 else { return false }
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}
