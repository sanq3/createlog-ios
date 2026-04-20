import SwiftUI

/// 設定 → アカウント → ブロック済みアカウント。
/// X / Instagram / Facebook 踏襲: ブロックした相手を一覧 + 解除できる場所を設定内に用意する。
/// 相手のプロフィールを直接開かなくても「誰をブロックしたか」確認・解除できる。
struct BlockedUsersView: View {
    @Environment(\.dependencies) private var dependencies

    @State private var rows: [BlockedUserRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var unblockingUserId: UUID?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color.clBackground)
        .navigationTitle("settings.privacy.blockedUsers")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .alert("common.error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "nosign")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.clTextTertiary)
            Text("settings.privacy.blockedUsers.empty")
                .font(.clBody)
                .foregroundStyle(Color.clTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            Section {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        AvatarView(
                            initials: initials(for: row.displayName),
                            size: 40,
                            status: .offline,
                            imageURL: row.avatarUrl.flatMap(URL.init(string:))
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.displayName)
                                .font(.clBody)
                                .foregroundStyle(Color.clTextPrimary)
                                .lineLimit(1)
                            if let handle = row.handle {
                                Text("@\(handle)")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            Task { await unblock(row) }
                        } label: {
                            if unblockingUserId == row.id {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("profile.unblock")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.clBorder.opacity(0.4), in: .capsule)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(unblockingUserId != nil)
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("settings.privacy.blockedUsers.footer")
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rows = try await dependencies.ugcRepository.fetchBlockedUsers()
        } catch {
            errorMessage = String(localized: "settings.privacy.blockedUsers.loadFailed")
        }
    }

    private func unblock(_ row: BlockedUserRow) async {
        unblockingUserId = row.id
        defer { unblockingUserId = nil }
        do {
            try await dependencies.ugcRepository.unblockUser(userId: row.id)
            HapticManager.success()
            rows.removeAll { $0.id == row.id }
        } catch {
            errorMessage = String(localized: "settings.privacy.blockedUsers.unblockFailed")
        }
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(1)).uppercased()
    }
}
