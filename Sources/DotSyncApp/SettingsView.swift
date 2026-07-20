import DotSyncCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SyncViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("GitHub") {
                HStack {
                    Text("Account").foregroundStyle(.secondary)
                    Spacer()
                    accountPicker
                }
                labeledRow("Host", model.settings.github.host)
                HStack {
                    Text("Repo name").foregroundStyle(.secondary)
                    Spacer()
                    TextField("dotsync-{id}", text: repoTemplateBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                        .font(.caption)
                }
                badge("Private only", "lock.fill", .green)
            }

            section("Discovery") {
                Toggle("Auto-add ~/.claude and ~/.codex", isOn: autoAddBinding)
                    .font(.callout)
                Text(model.settings.discovery.paths.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            section("Automation") {
                Toggle("Auto-sync", isOn: autoSyncBinding)
                    .font(.callout)
                HStack {
                    Text("Every").foregroundStyle(.secondary)
                    Spacer()
                    intervalPicker
                }
                .font(.caption)
                Toggle("Sync on file change", isOn: watchBinding)
                    .font(.callout)
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .font(.callout)
            }

            section("Safety") {
                badge("Block on tracked secrets", "exclamationmark.shield.fill", .orange)
                badge("Ask before creating remote", "hand.raised.fill", .blue)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onAppear { model.loadAccounts() }
    }

    private var accountPicker: some View {
        Menu {
            ForEach(model.ghAccounts, id: \.login) { account in
                Button {
                    model.settings.github.account = account.login
                    model.settings.github.host = account.host
                    model.saveSettings()
                } label: {
                    Label(account.login, systemImage: account.active ? "checkmark" : "person")
                }
            }
        } label: {
            Text(model.settings.github.account ?? "Select\u{2026}")
                .font(.caption.weight(.medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var repoTemplateBinding: Binding<String> {
        Binding(
            get: { model.settings.github.repoNameTemplate },
            set: {
                model.settings.github.repoNameTemplate = $0
                model.saveSettings()
            }
        )
    }

    private var autoAddBinding: Binding<Bool> {
        Binding(
            get: { model.settings.discovery.autoAdd },
            set: {
                model.settings.discovery.autoAdd = $0
                model.saveSettings()
            }
        )
    }

    private var autoSyncBinding: Binding<Bool> {
        Binding(
            get: { model.settings.autosync.enabled },
            set: {
                model.settings.autosync.enabled = $0
                model.saveSettings()
                model.applyAutoSync()
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.settings.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    }

    private var watchBinding: Binding<Bool> {
        Binding(
            get: { model.settings.autosync.watch },
            set: {
                model.settings.autosync.watch = $0
                model.saveSettings()
                model.applyWatch()
            }
        )
    }

    private var intervalPicker: some View {
        Menu {
            ForEach(intervalOptions, id: \.0) { seconds, label in
                Button(label) {
                    model.settings.autosync.intervalSec = seconds
                    model.saveSettings()
                    model.applyAutoSync()
                }
            }
        } label: {
            Text(intervalLabel).font(.caption.weight(.medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var intervalOptions: [(Int, String)] {
        [(60, "1 min"), (300, "5 min"), (900, "15 min"), (1800, "30 min"), (3600, "1 hour")]
    }

    private var intervalLabel: String {
        intervalOptions.first { $0.0 == model.settings.autosync.intervalSec }?.1
            ?? "\(model.settings.autosync.intervalSec)s"
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            content()
        }
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(.primary)
        }
        .font(.caption)
    }

    private func badge(_ text: String, _ symbol: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(color)
    }
}
