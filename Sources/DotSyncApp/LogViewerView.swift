import AppKit
import SwiftUI

struct LogViewerView: View {
    @SwiftUI.State private var entries: [LogEntry] = []
    @SwiftUI.State private var hours = 6
    @SwiftUI.State private var loading = false
    @SwiftUI.State private var query = ""
    @SwiftUI.State private var selection: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Table(filtered, selection: $selection) {
                TableColumn("Time") { entry in
                    Text(entry.time)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .width(70)

                TableColumn("Category") { entry in
                    Text(entry.category)
                        .foregroundStyle(.secondary)
                }
                .width(min: 70, ideal: 90, max: 140)

                TableColumn("Message") { entry in
                    Text(entry.message)
                        .foregroundStyle(entry.isError ? Color.red : .primary)
                        .help(entry.message)
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .overlay { emptyState }
            .navigationTitle("dotsync logs")
            .navigationSubtitle(subtitle)
            .searchable(text: $query, placement: .toolbar, prompt: "Filter")
            .toolbar { toolbarContent }
        }
        .frame(minWidth: 700, minHeight: 420)
        .onAppear(perform: load)
        .onChange(of: hours) { _, _ in load() }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("Range", selection: $hours) {
                Text("1h").tag(1)
                Text("6h").tag(6)
                Text("24h").tag(24)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        ToolbarItemGroup {
            Button(action: copy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(filtered.isEmpty)
            .help("Copy the listed entries")

            Button(action: save) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(filtered.isEmpty)
            .help("Save the listed entries to a file")

            Button(action: load) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Reload")
        }
    }

    @ViewBuilder private var emptyState: some View {
        if loading {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
        }
        if !loading, entries.isEmpty {
            ContentUnavailableView(
                "No entries",
                systemImage: "text.page",
                description: Text("Nothing was logged in the last \(hours) hours.")
            )
            .background(.background)
        }
        if !loading, !entries.isEmpty, filtered.isEmpty {
            ContentUnavailableView.search(text: query)
                .background(.background)
        }
    }

    private var filtered: [LogEntry] {
        let term = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return entries }
        return entries.filter {
            $0.message.lowercased().contains(term) || $0.category.lowercased().contains(term)
        }
    }

    private var subtitle: String {
        let count = filtered.count
        let noun = count == 1 ? "entry" : "entries"
        return "\(count) \(noun)"
    }

    private func load() {
        loading = true
        let window = hours
        Task.detached {
            let found = Diagnostics.entries(hours: window)
            await MainActor.run {
                entries = found
                loading = false
            }
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Diagnostics.plainText(filtered), forType: .string)
    }

    private func save() {
        guard let url = Diagnostics.save(Diagnostics.plainText(filtered)) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
