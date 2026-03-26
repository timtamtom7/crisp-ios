import SwiftUI

/// Anonymous community feed for sharing Crisp recordings.
struct CommunityView: View {
    @StateObject private var communityService = CommunityService.shared
    @State private var selectedTab: CommunityTab = .feed
    @State private var isSharing = false
    @State private var selectedNote: VoiceNote?
    @State private var showShareSheet = false

    enum CommunityTab: String, CaseIterable {
        case feed = "Feed"
        case trending = "Trending"
        case myShares = "My Shares"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab bar
                    HStack(spacing: 0) {
                        ForEach(CommunityTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(DesignTokens.easeOut) {
                                    selectedTab = tab
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                                        .foregroundColor(selectedTab == tab ? DesignTokens.accent : DesignTokens.textSecondary)

                                    Rectangle()
                                        .fill(selectedTab == tab ? DesignTokens.accent : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Divider()
                        .background(DesignTokens.textSecondary.opacity(0.1))

                    // Content
                    TabView(selection: $selectedTab) {
                        feedView.tag(CommunityTab.feed)
                        trendingView.tag(CommunityTab.trending)
                        mySharesView.tag(CommunityTab.myShares)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.accent)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                CommunityShareSheet(onShare: { note in
                    Task {
                        await communityService.shareNote(note)
                    }
                })
            }
        }
        .task {
            await communityService.loadFeed()
        }
    }

    // MARK: - Feed View

    private var feedView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if communityService.feedItems.isEmpty && !communityService.isLoading {
                    emptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No recordings shared yet",
                        subtitle: "Be the first to share an anonymous recording with the community."
                    )
                } else {
                    ForEach(communityService.feedItems) { item in
                        CommunityItemCard(item: item, onUpvote: {
                            Task { await communityService.upvote(item.id) }
                        }, onReport: {
                            Task { await communityService.report(item.id) }
                        })
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .refreshable {
            await communityService.loadFeed()
        }
    }

    // MARK: - Trending View

    private var trendingView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if communityService.trendingItems.isEmpty {
                    emptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Nothing trending yet",
                        subtitle: "Trending recordings will appear here based on upvotes."
                    )
                } else {
                    ForEach(communityService.trendingItems) { item in
                        CommunityItemCard(item: item, onUpvote: {
                            Task { await communityService.upvote(item.id) }
                        }, onReport: {
                            Task { await communityService.report(item.id) }
                        }, showRank: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .refreshable {
            await communityService.loadTrending()
        }
    }

    // MARK: - My Shares View

    private var mySharesView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if communityService.myShares.isEmpty {
                    emptyStateView(
                        icon: "square.and.arrow.up",
                        title: "You haven't shared anything",
                        subtitle: "Share your first recording anonymously with the community."
                    )
                } else {
                    ForEach(communityService.myShares) { item in
                        CommunityItemCard(item: item, onUpvote: nil, onReport: nil, isOwn: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(DesignTokens.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.accent)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Community Item Card

struct CommunityItemCard: View {
    let item: CommunityFeedItem
    let onUpvote: (() -> Void)?
    let onReport: (() -> Void)?
    var showRank: Bool = false
    var isOwn: Bool = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    if showRank, let rank = item.rank {
                        Text("#\(rank)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignTokens.accent)
                            .frame(width: 32)
                    }

                    // Topic badge
                    Text(item.topic)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(topicColor(for: item.topic))
                        .clipShape(Capsule())

                    Spacer()

                    if isOwn {
                        Text("Your share")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.textSecondary)
                    } else {
                        Text(item.formattedTime)
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                }

                // Content preview
                Text(item.preview)
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.textPrimary)
                    .lineLimit(3)

                // Stats and actions
                HStack {
                    // Upvotes
                    if let onUpvote = onUpvote {
                        Button(action: onUpvote) {
                            HStack(spacing: 4) {
                                Image(systemName: item.hasUpvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(item.hasUpvoted ? DesignTokens.accent : DesignTokens.textSecondary)

                                Text("\(item.upvotes)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignTokens.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else if isOwn {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 16))
                                .foregroundColor(DesignTokens.textSecondary)
                            Text("\(item.upvotes)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignTokens.textSecondary)
                        }
                    }

                    // Anonymous listeners
                    HStack(spacing: 4) {
                        Image(systemName: "headphones")
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.textSecondary)
                        Text("\(item.views) listens")
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.textSecondary)
                    }

                    Spacer()

                    if let onReport = onReport, !isOwn {
                        Button(action: onReport) {
                            Image(systemName: "flag")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.textSecondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
        }
    }

    private func topicColor(for topic: String) -> Color {
        switch topic {
        case "Meeting": return .blue
        case "Personal": return .pink
        case "Idea": return .yellow
        case "Tutorial": return .green
        case "News": return .orange
        case "Health": return .red
        case "Work": return .purple
        default: return DesignTokens.accent
        }
    }
}

// MARK: - Community Share Sheet

struct CommunityShareSheet: View {
    let onShare: (VoiceNote) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var notes: [VoiceNote] = []
    @State private var isLoading = true
    @State private var selectedNoteId: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(DesignTokens.accent)
                } else if notes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.slash")
                            .font(.system(size: 40))
                            .foregroundColor(DesignTokens.textSecondary)

                        Text("No recordings to share")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignTokens.textPrimary)

                        Text("Create your first recording to share it with the community.")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            Text("Select a recording to share anonymously")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(notes) { note in
                                Button {
                                    selectedNoteId = note.id
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedNoteId == note.id ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedNoteId == note.id ? DesignTokens.accent : DesignTokens.textSecondary)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(note.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(DesignTokens.textPrimary)
                                                .lineLimit(1)

                                            Text("\(note.formattedDate) · \(note.formattedDuration)")
                                                .font(.system(size: 12))
                                                .foregroundColor(DesignTokens.textSecondary)
                                        }

                                        Spacer()

                                        if let topic = note.topic {
                                            Text(topic)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(DesignTokens.accent)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                                            .fill(selectedNoteId == note.id ? DesignTokens.accent.opacity(0.1) : DesignTokens.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                                                    .stroke(selectedNoteId == note.id ? DesignTokens.accent.opacity(0.4) : DesignTokens.textSecondary.opacity(0.1), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Share to Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        if let noteId = selectedNoteId,
                           let note = notes.first(where: { $0.id == noteId }) {
                            onShare(note)
                            dismiss()
                        }
                    }
                    .disabled(selectedNoteId == nil)
                    .foregroundColor(selectedNoteId == nil ? DesignTokens.textSecondary : DesignTokens.accent)
                }
            }
            .task {
                await loadNotes()
            }
        }
    }

    private func loadNotes() async {
        isLoading = true
        do {
            notes = try DatabaseService.shared.fetchAllNotes()
        } catch {
            notes = []
        }
        isLoading = false
    }
}

// MARK: - Community Service

@MainActor
final class CommunityService: ObservableObject {
    static let shared = CommunityService()

    @Published var feedItems: [CommunityFeedItem] = []
    @Published var trendingItems: [CommunityFeedItem] = []
    @Published var myShares: [CommunityFeedItem] = []
    @Published var isLoading = false

    private let feedKey = "crisp_community_feed_v1"
    private let mySharesKey = "crisp_my_shares_v1"

    func loadFeed() async {
        await MainActor.run { isLoading = true }
        // Load from local storage (in a real app, this would be from a server)
        let items: [CommunityFeedItem] = UserDefaults.standard.decode([CommunityFeedItem].self, forKey: feedKey) ?? []
        await MainActor.run {
            feedItems = items.sorted { $0.upvotes > $1.upvotes }
            isLoading = false
        }
    }

    func loadTrending() async {
        await loadFeed()
        await MainActor.run {
            trendingItems = Array(feedItems.prefix(10))
        }
    }

    func loadMyShares() async {
        await MainActor.run {
            myShares = UserDefaults.standard.decode([CommunityFeedItem].self, forKey: mySharesKey) ?? []
        }
    }

    func shareNote(_ note: VoiceNote) async {
        let item = CommunityFeedItem(
            id: UUID(),
            noteId: note.id,
            topic: note.topic ?? "Other",
            preview: String(note.transcription.prefix(200)),
            upvotes: 0,
            views: 0,
            hasUpvoted: false,
            createdAt: Date(),
            isOwn: true
        )
        await MainActor.run {
            myShares.insert(item, at: 0)
            UserDefaults.standard.encode(myShares, forKey: mySharesKey)
        }
    }

    func upvote(_ itemId: UUID) async {
        await MainActor.run {
            if let idx = feedItems.firstIndex(where: { $0.id == itemId }) {
                var item = feedItems[idx]
                if !item.hasUpvoted {
                    item.upvotes += 1
                    item.hasUpvoted = true
                    feedItems[idx] = item
                }
            }
        }
    }

    func report(_ itemId: UUID) async {
        await MainActor.run {
            feedItems.removeAll { $0.id == itemId }
            UserDefaults.standard.encode(feedItems, forKey: feedKey)
        }
    }
}

// MARK: - Community Feed Item

struct CommunityFeedItem: Identifiable, Codable {
    let id: UUID
    let noteId: UUID
    let topic: String
    let preview: String
    var upvotes: Int
    var views: Int
    var hasUpvoted: Bool
    let createdAt: Date
    var isOwn: Bool
    var rank: Int?

    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - UserDefaults Codable Extension

extension UserDefaults {
    func encode<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            set(data, forKey: key)
        }
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
