import SwiftUI
import SwiftData

struct RecordingView: View {
    /// 2026-04-20: MainTabView @State から inject される。tab 切替で identity 破壊されない。
    @Bindable var viewModel: RecordingViewModel
    @Binding var tabBarOffset: CGFloat
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var deps

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()
            mainContent
        }
        .navigationTitle("recording.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 初回: サーバ同期を実行。再訪時は local 再読み込みのみ。
            viewModel.loadData()
            await viewModel.syncWithRemote()
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Stats + integrated picker wheels
                TodayHeroView(
                    metrics: viewModel.heroMetrics,
                    pickerHours: Binding(get: { viewModel.pickerHours }, set: { viewModel.pickerHours = $0 }),
                    pickerMinutes: Binding(get: { viewModel.pickerMinutes }, set: { viewModel.pickerMinutes = $0 })
                )
                .padding(.horizontal, 16)

                // Active timer
                if viewModel.isTimerRunning {
                    timerBanner(viewModel)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                // Tag + record button
                TimePickerSection(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Tags
                TagChipsView(
                    tags: viewModel.tags,
                    selectedTag: viewModel.selectedTag,
                    onTagTapped: { viewModel.selectTag($0) },
                    onTagLongPressed: { viewModel.startTimer(for: $0) },
                    onAddTapped: { viewModel.startCreateTag() }
                )
                .padding(.top, 20)

                if viewModel.tags.isEmpty {
                    emptyTagsHint
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                // History
                RecentHistoryView(entries: viewModel.recentEntries)
                    .padding(.top, 20)
                    .padding(.horizontal, 16)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: showCreateTagBinding) {
            TagCreationWizard(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .errorBanner(Binding(
            get: { viewModel.errorMessage },
            set: { viewModel.errorMessage = $0 }
        ))
    }

    private var showCreateTagBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showCreateTag },
            set: { newValue in viewModel.showCreateTag = newValue }
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
            Text("onboarding.tagIntro.title")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.clTextPrimary)
            Text("onboarding.tagIntro.subtitle")
                .font(.system(size: 13))
                .foregroundStyle(Color.clTextTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }
}
