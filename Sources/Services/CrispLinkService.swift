import Foundation

/// Service for creating and managing ephemeral "Crisp Links" — shareable,
/// listen-once voice note links that expire after a set time or plays.
struct CrispLink: Codable, Identifiable {
    let id: UUID
    let noteId: UUID
    let audioFileName: String
    let createdAt: Date
    let expiresAt: Date
    var playCount: Int
    let maxPlays: Int   // 1 = listen once
    let isPublic: Bool

    var isExpired: Bool {
        Date() > expiresAt || playCount >= maxPlays
    }

    var shareURL: URL? {
        URL(string: "https://crisp.link/\(id.uuidString.lowercased())")
    }
}

enum CrispLinkError: LocalizedError {
    case noAudioFile
    case uploadFailed
    case linkNotFound
    case linkExpired
    case maxPlaysReached

    var errorDescription: String? {
        switch self {
        case .noAudioFile: return "Audio file not found"
        case .uploadFailed: return "Failed to upload recording"
        case .linkNotFound: return "Crisp link not found"
        case .linkExpired: return "This Crisp link has expired"
        case .maxPlaysReached: return "This link has reached its maximum plays"
        }
    }
}

final class CrispLinkService: ObservableObject, @unchecked Sendable {
    static let shared = CrispLinkService()

    @Published private(set) var activeLinks: [CrispLink] = []
    @Published private(set) var pendingUpload: Bool = false

    private let linksKey = "crisp_links_v1"
    private let storageDir: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        storageDir = docs.appendingPathComponent("CrispLinks", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        loadLinks()
    }

    // MARK: - Public API

    /// Creates a Crisp Link for a voice note.
    /// - Parameters:
    ///   - note: The voice note to share
    ///   - expiresIn: Time until link expires (default: 7 days)
    ///   - maxPlays: Maximum times link can be played (default: 1 for listen-once)
    /// - Returns: The created CrispLink
    @discardableResult
    func createLink(
        for note: VoiceNote,
        expiresIn: TimeInterval = 7 * 24 * 60 * 60,
        maxPlays: Int = 1
    ) async throws -> CrispLink {
        pendingUpload = true
        defer { pendingUpload = false }

        // Verify audio file exists
        guard FileManager.default.fileExists(atPath: note.audioFileURL.path) else {
            throw CrispLinkError.noAudioFile
        }

        // Copy audio to CrispLinks storage
        let linkId = UUID()
        let ext = note.audioFileURL.pathExtension
        let storedFileName = "\(linkId.uuidString.lowercased()).\(ext)"
        let storedURL = storageDir.appendingPathComponent(storedFileName)

        try FileManager.default.copyItem(at: note.audioFileURL, to: storedURL)

        let link = CrispLink(
            id: linkId,
            noteId: note.id,
            audioFileName: storedFileName,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(expiresIn),
            playCount: 0,
            maxPlays: maxPlays,
            isPublic: true
        )

        await MainActor.run {
            activeLinks.insert(link, at: 0)
            saveLinks()
        }

        return link
    }

    /// Records a play of a link. Throws if expired or max plays reached.
    func recordPlay(linkId: UUID) throws {
        guard let idx = activeLinks.firstIndex(where: { $0.id == linkId }) else {
            throw CrispLinkError.linkNotFound
        }

        let link = activeLinks[idx]

        if link.isExpired {
            throw link.expiresAt > Date() ? CrispLinkError.maxPlaysReached : CrispLinkError.linkExpired
        }

        activeLinks[idx].playCount += 1
        saveLinks()
    }

    /// Returns the local audio URL for a Crisp Link if still valid.
    func audioURL(for linkId: UUID) throws -> URL {
        guard let link = activeLinks.first(where: { $0.id == linkId }) else {
            throw CrispLinkError.linkNotFound
        }

        if link.isExpired {
            throw link.playCount >= link.maxPlays ? CrispLinkError.maxPlaysReached : CrispLinkError.linkExpired
        }

        return storageDir.appendingPathComponent(link.audioFileName)
    }

    /// Deletes a Crisp Link manually.
    func deleteLink(id: UUID) {
        if let idx = activeLinks.firstIndex(where: { $0.id == id }) {
            let link = activeLinks[idx]
            let url = storageDir.appendingPathComponent(link.audioFileName)
            try? FileManager.default.removeItem(at: url)
            activeLinks.remove(at: idx)
            saveLinks()
        }
    }

    /// Cleans up expired links.
    func cleanupExpired() {
        let expired = activeLinks.filter { $0.isExpired }
        for link in expired {
            let url = storageDir.appendingPathComponent(link.audioFileName)
            try? FileManager.default.removeItem(at: url)
        }
        activeLinks.removeAll { $0.isExpired }
        saveLinks()
    }

    /// Share text for a Crisp Link using UIActivityViewController.
    @MainActor
    func shareLink(_ link: CrispLink, from viewController: UIViewController) {
        guard let url = link.shareURL else { return }

        let listenOnceText = link.maxPlays == 1 ? "Listen once · " : ""
        let expiresText = "Expires in 7 days"
        let shareText = "Listen to my Crisp voice note: \(listenOnceText)\(expiresText)\n\(url.absoluteString)"

        let activityVC = UIActivityViewController(
            activityItems: [shareText, url],
            applicationActivities: nil
        )
        viewController.present(activityVC, animated: true)
    }

    // MARK: - Persistence

    private func loadLinks() {
        guard let data = UserDefaults.standard.data(forKey: linksKey) else { return }
        activeLinks = (try? JSONDecoder().decode([CrispLink].self, from: data)) ?? []
        cleanupExpired()
    }

    private func saveLinks() {
        let data = try? JSONEncoder().encode(activeLinks)
        UserDefaults.standard.set(data, forKey: linksKey)
    }
}

// MARK: - CrispLink Share Sheet

import SwiftUI

struct CrispLinkSheet: View {
    let note: VoiceNote
    let onDismiss: () -> Void

    @StateObject private var linkService = CrispLinkService.shared
    @State private var isCreating = false
    @State private var createdLink: CrispLink?
    @State private var error: String?
    @State private var linkType: LinkType = .listenOnce

    @Environment(\.dismiss) private var dismiss

    enum LinkType: String, CaseIterable {
        case listenOnce = "Listen Once"
        case multiplePlays = "Multiple Plays"
        case weekLong = "7-Day Link"

        var maxPlays: Int {
            switch self {
            case .listenOnce: return 1
            case .multiplePlays: return 5
            case .weekLong: return 10
            }
        }

        var expiresIn: TimeInterval {
            switch self {
            case .listenOnce: return 7 * 24 * 60 * 60
            case .multiplePlays: return 3 * 24 * 60 * 60
            case .weekLong: return 7 * 24 * 60 * 60
            }
        }

        var description: String {
            switch self {
            case .listenOnce: return "Link expires after one listen"
            case .multiplePlays: return "Up to 5 plays, expires in 3 days"
            case .weekLong: return "Up to 10 plays, expires in 7 days"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Info header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(DesignTokens.accent.opacity(0.15))
                                .frame(width: 64, height: 64)

                            Image(systemName: "link")
                                .font(.system(size: 26))
                                .foregroundColor(DesignTokens.accent)
                        }

                        Text("Share as Crisp Link")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignTokens.textPrimary)

                        Text("Create a shareable link to your recording. No account needed to listen.")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)

                    // Link type picker
                    VStack(spacing: 10) {
                        ForEach(LinkType.allCases, id: \.self) { type in
                            LinkTypeRow(
                                type: type,
                                isSelected: linkType == type,
                                onTap: { linkType = type }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    if let error = error {
                        InlineErrorBanner(
                            title: "Failed to create link",
                            message: error,
                            icon: "exclamationmark.triangle",
                            onDismiss: { self.error = nil }
                        )
                    }

                    if let link = createdLink {
                        // Link created view
                        VStack(spacing: 16) {
                            // URL display
                            VStack(spacing: 6) {
                                Text("Your Crisp Link")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DesignTokens.textSecondary)

                                if let url = link.shareURL {
                                    Text(url.absoluteString)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(DesignTokens.accent)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                            }
                            .padding(12)
                            .background(DesignTokens.surface)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))

                            // Expiry info
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                Text(expiresText(for: link))
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(DesignTokens.textSecondary)

                            Button {
                                shareLink(link)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14))
                                    Text("Share Link")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(DesignTokens.background)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(DesignTokens.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                copyLink(link)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14))
                                    Text("Copy Link")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(DesignTokens.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(DesignTokens.accent.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        Button {
                            createLink()
                        } label: {
                            HStack(spacing: 6) {
                                if isCreating {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(DesignTokens.background)
                                } else {
                                    Image(systemName: "link.badge.plus")
                                        .font(.system(size: 14))
                                }
                                Text("Create Crisp Link")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(DesignTokens.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(DesignTokens.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isCreating)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Crisp Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func expiresText(for link: CrispLink) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Expires \(formatter.localizedString(for: link.expiresAt, relativeTo: Date()))"
    }

    private func createLink() {
        isCreating = true
        error = nil

        Task {
            do {
                let link = try await CrispLinkService.shared.createLink(
                    for: note,
                    expiresIn: linkType.expiresIn,
                    maxPlays: linkType.maxPlays
                )
                await MainActor.run {
                    createdLink = link
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }

    private func shareLink(_ link: CrispLink) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        CrispLinkService.shared.shareLink(link, from: rootVC)
    }

    private func copyLink(_ link: CrispLink) {
        if let url = link.shareURL {
            UIPasteboard.general.string = url.absoluteString
        }
    }
}

struct LinkTypeRow: View {
    let type: CrispLinkSheet.LinkType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? DesignTokens.accent : DesignTokens.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.textPrimary)

                    Text(type.description)
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.textSecondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                    .fill(isSelected ? DesignTokens.accent.opacity(0.08) : DesignTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                            .stroke(isSelected ? DesignTokens.accent.opacity(0.4) : DesignTokens.textSecondary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Crisp Link Card (for NoteDetailView)

struct CrispLinkCard: View {
    let note: VoiceNote
    @State private var showCrispLinkSheet = false
    @State private var showProUpgradePrompt = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        Button {
            if subscriptionManager.tier.isPro {
                showCrispLinkSheet = true
            } else {
                showProUpgradePrompt = true
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(DesignTokens.accent.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "link")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Share as Crisp Link")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignTokens.textPrimary)

                    Text("Create an ephemeral link to share")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.textSecondary)
            }
            .padding(12)
            .background(DesignTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCrispLinkSheet) {
            CrispLinkSheet(note: note, onDismiss: {})
        }
        .sheet(isPresented: $showProUpgradePrompt) {
            ProUpgradeSheet(feature: "Crisp Links", onUpgrade: {})
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}
