import SwiftUI
import UIKit

/// 時間・分の両方がループするピッカー（オンボーディング等で使用）
struct DurationPicker: UIViewRepresentable {
    @Binding var hours: Int
    @Binding var minutes: Int

    private static let maxHours = 24
    private static let minuteInterval = 5
    private static let minuteSlots = 60 / minuteInterval
    private static let loopMultiplier = 100

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator

        let midH = (Self.loopMultiplier / 2) * Self.maxHours + hours
        let midM = (Self.loopMultiplier / 2) * Self.minuteSlots + (minutes / Self.minuteInterval)
        picker.selectRow(midH, inComponent: 0, animated: false)
        picker.selectRow(midM, inComponent: 1, animated: false)

        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {}

    func makeCoordinator() -> DurationCoordinator {
        DurationCoordinator(self)
    }

    final class DurationCoordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        let parent: DurationPicker

        init(_ parent: DurationPicker) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            if component == 0 {
                return DurationPicker.maxHours * DurationPicker.loopMultiplier
            } else {
                return DurationPicker.minuteSlots * DurationPicker.loopMultiplier
            }
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            if component == 0 {
                let h = row % DurationPicker.maxHours
                return "\(h) h"
            } else {
                let m = (row % DurationPicker.minuteSlots) * DurationPicker.minuteInterval
                return "\(m) m"
            }
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if component == 0 {
                parent.hours = row % DurationPicker.maxHours
            } else {
                parent.minutes = (row % DurationPicker.minuteSlots) * DurationPicker.minuteInterval
            }
        }
    }
}

/// 単一列のループするピッカー（時間 or 分に使用）
struct SingleColumnLoopingPicker: UIViewRepresentable {
    @Binding var value: Int
    let maxValue: Int
    let step: Int
    let suffix: String

    private var slotCount: Int { maxValue / step }
    private static let loopMultiplier = 100

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator

        let midRow = (Self.loopMultiplier / 2) * slotCount + (value / step)
        picker.selectRow(midRow, inComponent: 0, animated: false)

        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: SingleColumnLoopingPicker

        init(_ parent: SingleColumnLoopingPicker) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            parent.slotCount * SingleColumnLoopingPicker.loopMultiplier
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            let val = (row % parent.slotCount) * parent.step
            return "\(val) \(parent.suffix)"
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            parent.value = (row % parent.slotCount) * parent.step
        }
    }
}
