import DotSyncCore
import SwiftUI

struct MenuContent: View {
    @ObservedObject var model: SyncViewModel
    @SwiftUI.State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)

            ScrollView {
                if showSettings {
                    SettingsView(model: model)
                } else {
                    VStack(spacing: 0) {
                        folderList
                        Divider().opacity(0.25)
                        addButton
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 460)

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
            LazyVStack(spacing: 8) {
                ForEach(model.rows) { row in
                    card(for: row)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    private func card(for row: RootStatus) -> some View {
        VStack(spacing: 0) {
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
                onRemove: { model.removeRoot(row.id) },
                expanded: model.expandedID == row.id,
                onToggleDetail: { model.toggleDetail(row.id) })
            if model.expandedID == row.id, let detail = model.detail {
                Divider().opacity(0.15)
                RootDetailView(detail: detail)
            }
        }
        .background(
            RootRow.cardTint(
                setup: row.setup, conflict: row.conflict,
                blocked: model.blocked.contains(row.id))
        )
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
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
