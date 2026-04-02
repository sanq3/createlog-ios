import SwiftUI
import SwiftData

struct RecordingView: View {
    @Binding var tabBarOffset: CGFloat
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: RecordingViewModel?

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()
            mainContent
        }
        .navigationTitle("記録")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = RecordingViewModel(modelContext: modelContext)
                viewModel = vm
                vm.loadData()
            } else {
                viewModel?.loadData()
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Stats (glass card)
                TodayHeroView(
                    metrics: viewModel?.heroMetrics
                )
                .padding(.horizontal, 16)

                if let vm = viewModel {
                    // Active timer
                    if vm.isTimerRunning {
                        timerBanner(vm)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    // Picker + record button (always visible)
                    TimePickerSection(viewModel: vm)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Tags
                    TagChipsView(
                        tags: vm.tags,
                        selectedTag: vm.selectedTag,
                        onTagTapped: { vm.selectTag($0) },
                        onTagLongPressed: { vm.startTimer(for: $0) },
                        onAddTapped: { vm.startCreateTag() }
                    )
                    .padding(.top, 20)

                    if vm.tags.isEmpty {
                        emptyTagsHint
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    // History
                    RecentHistoryView(entries: vm.recentEntries)
                        .padding(.top, 20)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: showCreateTagBinding) {
            if let vm = viewModel {
                TagCreationWizard(viewModel: vm)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var showCreateTagBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showCreateTag ?? false },
            set: { newValue in viewModel?.showCreateTag = newValue }
        )
    }

    // MARK: - Timer Banner

    private func timerBanner(_ vm: RecordingViewModel) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.clRecording)
                .frame(width: 8, height: 8)
                .modifier(PulseModifier())

            if let tag = vm.timerTag {
                Text(tag.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
            }

            Spacer()

            Text(vm.timerFormatted)
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.clRecording)
                .tabularNumbers()
                .contentTransition(.numericText())

            Button {
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    vm.stopTimer()
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.clRecording, in: Circle())
            }
            .buttonStyle(.bounce)

            Button {
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    vm.cancelTimer()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.clTextTertiary)
                    .padding(8)
                    .background(Color.clSurfaceLow, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.clRecording.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.clRecording.opacity(0.15), lineWidth: 1)
                )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var emptyTagsHint: some View {
        VStack(spacing: 8) {
            Text("記録する項目を作ろう")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.clTextPrimary)
            Text("よくやる作業をタグとして登録すると\nタップ+時間入力だけで記録できます")
                .font(.system(size: 13))
                .foregroundStyle(Color.clTextTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }
}
