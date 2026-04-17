import SwiftUI

struct TagCreationWizard: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isProjectNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            stepIndicator
            Divider()
            stepContent
        }
        .onDisappear {
            viewModel.resetWizard()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if viewModel.wizardStep > 0 {
                Button {
                    withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                        viewModel.goBackWizard()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(wizardTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.clTextTertiary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { step in
                Capsule()
                    .fill(step <= viewModel.wizardStep ? Color.clAccent : Color.clBorder)
                    .frame(height: 3)
                    .animation(.spring(duration: 0.3, bounce: 0.15), value: viewModel.wizardStep)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Step Content

    private var stepContent: some View {
        ScrollView {
            VStack(spacing: 6) {
                switch viewModel.wizardStep {
                case 0: genreStep
                case 1: activityStep
                case 2: projectNameStep
                default: EmptyView()
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 320)
    }

    private var wizardTitle: String {
        switch viewModel.wizardStep {
        case 0: return "ジャンルは？"
        case 1: return "何をする？"
        case 2: return "プロジェクト名（任意）"
        default: return ""
        }
    }

    // MARK: - Genre Step

    private var genreStep: some View {
        ForEach(Array(RecordingViewModel.genres.enumerated()), id: \.element.name) { index, genre in
            Button {
                withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                    viewModel.selectGenre(genre.name)
                }
            } label: {
                HStack {
                    Text(genre.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.clSurfaceLow)
                )
            }
            .buttonStyle(.bounce)
            .transition(.push(from: .trailing))
        }
    }

    // MARK: - Activity Step

    private var activityStep: some View {
        let activities = RecordingViewModel.genres.first(where: { $0.name == viewModel.selectedGenre })?.activities ?? []
        return ForEach(activities, id: \.self) { activity in
            Button {
                withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                    viewModel.selectActivity(activity)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    isProjectNameFocused = true
                }
            } label: {
                HStack {
                    Text(activity)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.clSurfaceLow)
                )
            }
            .buttonStyle(.bounce)
            .transition(.push(from: .trailing))
        }
    }

    // MARK: - Project Name Step

    @State private var showNewProjectInput = false

    private var projectNameStep: some View {
        VStack(spacing: 12) {
            Text(viewModel.selectedActivity)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.clAccent)

            // Existing projects to pick from
            if !viewModel.existingProjectNames.isEmpty {
                ForEach(viewModel.existingProjectNames, id: \.self) { name in
                    Button {
                        viewModel.saveTag(withProjectName: name)
                        dismiss()
                    } label: {
                        HStack {
                            Text(name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.clTextPrimary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.clAccent)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.clSurfaceLow)
                        )
                    }
                    .buttonStyle(.bounce)
                }
            }

            // New project input
            if showNewProjectInput {
                HStack(spacing: 8) {
                    TextField("onboarding.project.service.input", text: $viewModel.projectName)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.clTextPrimary)
                        .focused($isProjectNameFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.clSurfaceLow)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.clBorder, lineWidth: 1)
                                )
                        )

                    Button {
                        viewModel.saveTag(withProjectName: viewModel.projectName.isEmpty ? nil : viewModel.projectName)
                        dismiss()
                    } label: {
                        Text("common.create")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.clAccent, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.bounce)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                        showNewProjectInput = true
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        isProjectNameFocused = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                        Text("profile.myProducts.add")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.clTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.clBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    )
                }
                .buttonStyle(.bounce)
            }

            // Skip
            Button {
                viewModel.saveTag(withProjectName: nil)
                dismiss()
            } label: {
                Text("common.skipNoProduct")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .transition(.push(from: .trailing))
    }
}
