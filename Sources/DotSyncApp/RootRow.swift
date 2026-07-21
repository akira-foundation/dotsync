import DotSyncCore
import SwiftUI

struct RootRow: View {
    let row: RootStatus
    let busy: Bool
    let blocked: Bool
    let onSync: () -> Void
    let onSetup: () -> Void
    let onResolve: () -> Void
    let onReveal: () -> Void
    let onToggleAuto: () -> Void
    let onRemove: () -> Void
    let expanded: Bool
    let onToggleDetail: () -> Void
    @SwiftUI.State private var hover = false

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .shadow(color: dotColor.opacity(0.6), radius: 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Text(row.id)
                        .font(.system(.body, design: .rounded).weight(.medium))
                    if !row.auto {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .help("Auto-sync paused")
                    }
                    Spacer()
                    Text(statusText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(statusColor)
                }
                Label(pathDisplay, systemImage: "folder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Label(repoDisplay, systemImage: "cloud")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let synced = lastSyncDisplay {
                    Label(synced, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            trailingControl
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { onToggleDetail() }
        }
        .contextMenu {
            if let remote = row.remote, let url = URL(string: "https://" + shortRepo(remote)) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open on GitHub", systemImage: "arrow.up.right.square")
                }
            }
            Button(action: onReveal) {
                Label("Reveal in Finder", systemImage: "folder")
            }
            if row.setup == .ready {
                Button(action: onToggleAuto) {
                    Label(
                        row.auto ? "Pause auto-sync" : "Resume auto-sync",
                        systemImage: row.auto ? "pause.circle" : "play.circle")
                }
            }
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private enum TrailingControl {
        case busy
        case setup
        case conflict
        case sync
    }

    private var trailingKind: TrailingControl {
        if busy { return .busy }
        if row.setup != .ready { return .setup }
        if row.conflict { return .conflict }
        return .sync
    }

    @ViewBuilder private var trailingControl: some View {
        switch trailingKind {
        case .busy:
            ProgressView().controlSize(.small)
        case .setup:
            Button(action: onSetup) {
                Text("Set up").font(.caption.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .help("Create repo and push")
        case .conflict:
            Button(action: onResolve) {
                Text("Resolve").font(.caption.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .tint(.orange)
            .help("Resolve conflict")
        case .sync:
            Button(action: onSync) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help("Sync now")
        }
    }

    private var statusText: String {
        if blocked { return "secrets blocked" }
        switch row.setup {
        case .needsGit: return "not a repo"
        case .needsRemote: return "no remote"
        case .ready: break
        }
        if row.conflict { return "conflict" }
        if row.pending > 0 { return "\(row.pending) pending" }
        var parts: [String] = []
        if row.ahead > 0 { parts.append("\u{2191}\(row.ahead)") }
        if row.behind > 0 { parts.append("\u{2193}\(row.behind)") }
        return parts.isEmpty ? "synced" : parts.joined(separator: " ")
    }

    private var statusColor: Color {
        if blocked { return .red }
        if row.setup != .ready { return .blue }
        if row.conflict { return .orange }
        if row.pending > 0 || row.ahead > 0 || row.behind > 0 { return .yellow }
        return .green
    }

    private var dotColor: Color { statusColor }

    private var rowBackground: Color {
        if blocked { return Color.red.opacity(0.09) }
        if row.conflict { return Color.orange.opacity(0.09) }
        if row.setup != .ready { return Color.blue.opacity(0.07) }
        return hover ? Color.primary.opacity(0.06) : .clear
    }

    private var pathDisplay: String {
        (row.path as NSString).abbreviatingWithTildeInPath
    }

    private var repoDisplay: String {
        guard let remote = row.remote else { return "no remote \u{00B7} \(row.branch)" }
        return "\(shortRepo(remote)) \u{00B7} \(row.branch)"
    }

    private var lastSyncDisplay: String? {
        guard let timestamp = row.lastTimestamp else { return nil }
        guard let date = ISO8601DateFormatter().date(from: timestamp) else { return timestamp }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func shortRepo(_ url: String) -> String {
        var s = url
        if let range = s.range(of: "://") { s = String(s[range.upperBound...]) }
        s = s.replacingOccurrences(of: "git@", with: "")
        s = s.replacingOccurrences(of: ":", with: "/")
        if s.hasSuffix(".git") { s = String(s.dropLast(4)) }
        return s
    }
}
