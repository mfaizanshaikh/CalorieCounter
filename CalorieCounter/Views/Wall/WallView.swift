import SwiftUI

struct WallView: View {
    @StateObject private var viewModel = WallViewModel()
    @State private var reportingPost: WallPost?
    @State private var blockCandidate: WallPost?
    @State private var deleteCandidate: WallPost?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    Picker("Feed", selection: Binding(
                        get: { viewModel.sortMode },
                        set: { viewModel.setSortMode($0) }
                    )) {
                        ForEach(WallSortMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        ProgressView()
                            .padding(.top, 80)
                    } else if viewModel.posts.isEmpty {
                        ContentUnavailableView(
                            "No Wall Posts",
                            systemImage: "fork.knife.circle",
                            description: Text("Shared meals will appear here.")
                        )
                        .padding(.top, 80)
                    } else {
                        ForEach(viewModel.posts) { post in
                            WallPostCard(
                                post: post,
                                onLike: { Task { await viewModel.toggleLike(post) } },
                                onReport: { reportingPost = post },
                                onBlock: { blockCandidate = post },
                                onDelete: { deleteCandidate = post }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Wall")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Refresh wall")
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                if viewModel.posts.isEmpty {
                    await viewModel.load()
                }
            }
            .sheet(item: $reportingPost) { post in
                ReportWallPostSheet(post: post) { reason, details in
                    await viewModel.report(post, reason: reason, details: details)
                }
            }
            .confirmationDialog(
                "Block user?",
                isPresented: Binding(
                    get: { blockCandidate != nil },
                    set: { if !$0 { blockCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Block", role: .destructive) {
                    guard let post = blockCandidate else { return }
                    blockCandidate = nil
                    Task { await viewModel.block(post) }
                }
                Button("Cancel", role: .cancel) {
                    blockCandidate = nil
                }
            } message: {
                Text("Posts from this user will no longer appear on your wall.")
            }
            .confirmationDialog(
                "Delete post?",
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let post = deleteCandidate else { return }
                    deleteCandidate = nil
                    Task { await viewModel.delete(post) }
                }
                Button("Cancel", role: .cancel) {
                    deleteCandidate = nil
                }
            } message: {
                Text("This removes your shared meal from the public wall.")
            }
            .alert("Wall", isPresented: Binding(
                get: { viewModel.actionMessage != nil },
                set: { if !$0 { viewModel.actionMessage = nil } }
            )) {
                Button("OK") { viewModel.actionMessage = nil }
            } message: {
                Text(viewModel.actionMessage ?? "")
            }
            .alert("Wall Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

private struct WallPostCard: View {
    let post: WallPost
    let onLike: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WallRemotePhotoView(post: post)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(post.authorFirstName)
                            .font(.headline)
                        Text("|")
                            .foregroundStyle(.tertiary)
                        Text(relativePostedAt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Label(post.mealType, systemImage: MealType(rawValue: post.mealType)?.icon ?? "fork.knife")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        onReport()
                    } label: {
                        Label("Report Post", systemImage: "flag")
                    }

                    if !post.isMine {
                        Button(role: .destructive) {
                            onBlock()
                        } label: {
                            Label("Block User", systemImage: "person.crop.circle.badge.xmark")
                        }
                    }

                    if post.isMine {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete My Post", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Post actions")
            }

            Text(post.foodSummary)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(3)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(post.totalCaloriesAvg)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                Text("cal")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(post.totalCaloriesMin)-\(post.totalCaloriesMax)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let macrosText {
                Text(macrosText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 16) {
                Button(action: onLike) {
                    Label("\(post.likeCount)", systemImage: post.isLiked ? "heart.fill" : "heart")
                        .font(.subheadline)
                }
                .foregroundStyle(post.isLiked ? .red : .primary)

                Spacer()
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var relativePostedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: post.postedAt, relativeTo: Date())
    }

    private var macrosText: String? {
        var parts: [String] = []
        if let protein = post.protein { parts.append("Protein \(formattedMacro(protein))g") }
        if let carbs = post.carbs { parts.append("Carbs \(formattedMacro(carbs))g") }
        if let fat = post.fat { parts.append("Fat \(formattedMacro(fat))g") }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }

    private func formattedMacro(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

private struct WallRemotePhotoView: View {
    let post: WallPost
    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: post.id) {
            guard image == nil else { return }
            isLoading = true
            image = await WallPhotoLoader.shared.image(for: post)
            isLoading = false
        }
    }
}

private struct ReportWallPostSheet: View {
    let post: WallPost
    let onSubmit: (WallReportReason, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: WallReportReason = .offensiveContent
    @State private var details = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $reason) {
                        ForEach(WallReportReason.allCases) { reason in
                            Text(reason.title).tag(reason)
                        }
                    }
                }

                Section("Details") {
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                }

                Section {
                    Link("Contact Support", destination: URL(string: "mailto:mfaizan.shaikh@gmail.com")!)
                } footer: {
                    Text("For privacy or safety concerns, contact mfaizan.shaikh@gmail.com.")
                }
            }
            .navigationTitle("Report Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Sending..." : "Send") {
                        submit()
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
            await onSubmit(reason, trimmed.isEmpty ? nil : trimmed)
            isSubmitting = false
            dismiss()
        }
    }
}

#Preview {
    WallView()
}
