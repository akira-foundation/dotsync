import DotSyncCore
import SwiftUI

struct MenuContent: View {
    @ObservedObject var model: SyncViewModel
    @SwiftUI.State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)

            if showSettings {
                SettingsView(model: model)
            } else {
                folderList
                Divider().opacity(0.25)
                addButton
            }

            Divider().opacity(0.35)
            footer
        }
        .frame(width: 320)
        .animation(.easeInOut(duration: 0.2), value: model.rows)
        .animation(.easeInOut(duration: 0.2), value: model.busy)
        .onAppear { model.discover() }
    }

    @ViewBuilder private var folderList: some View {
        if model.rows.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                Text("No folders yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Add a folder below to start syncing")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                RootRow(
                    row: row,
                    busy: model.busy.contains(row.id),
                    blocked: model.blocked.contains(row.id),
                    onSync: { model.syncNow(row.id) },
                    onSetup: { model.onboard(row.id) },
                    onResolve: { model.resolveConflict(row.id) },
                    onReveal: {
                        NSWorkspace.shared.activateFileViewerSelecting([
                            URL(fileURLWithPath: row.path)
                        ])
                    },
                    onToggleAuto: { model.toggleAuto(row.id) },
                    onRemove: { model.removeRoot(row.id) })
                if index < model.rows.count - 1 {
                    Divider().opacity(0.25).padding(.leading, 34)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("dotsync")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Spacer()
            if !model.busy.isEmpty {
                ProgressView().controlSize(.mini)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showSettings.toggle() }
            } label: {
                Image(systemName: showSettings ? "chevron.left" : "gearshape")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help(showSettings ? "Back" : "Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var addButton: some View {
        Button {
            model.addFolder()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13))
                Text("Add folder\u{2026}")
                    .font(.callout)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var footer: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    model.syncAll()
                } label: {
                    Label("Sync all", systemImage: "arrow.triangle.2.circlepath")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(model.rows.isEmpty)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.glass)
                .help("Quit")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

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
    @SwiftUI.State private var hover = false

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .shadow(color: dotColor.opacity(0.6), radius: 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
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

            if busy {
                ProgressView().controlSize(.small)
            } else if row.setup != .ready {
                Button(action: onSetup) {
                    Text("Set up").font(.caption.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .help("Create repo and push")
            } else if row.conflict {
                Button(action: onResolve) {
                    Text("Resolve").font(.caption.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .tint(.orange)
                .help("Resolve conflict")
            } else {
                Button(action: onSync) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Sync now")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .contextMenu {
            Button("Reveal in Finder", action: onReveal)
            Button(row.auto ? "Pause auto-sync" : "Resume auto-sync", action: onToggleAuto)
            Button("Remove", role: .destructive, action: onRemove)
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
