import AppKit
import SwiftUI

struct LogViewerView: View {
    @SwiftUI.State private var entries: [LogEntry] = []
    @SwiftUI.State private var hours = 6
    @SwiftUI.State private var loading = false
    @SwiftUI.State private var savedName: String?

    private let ranges = [1, 6, 24]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 460)
        .onAppear(perform: load)
    }

    @ViewBuilder private var content: some View {
        if entries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: loading ? "hourglass" : "text.magnifyingglass")
                    .font(.system(size: 26))
                    .foregroundStyle(.tertiary)
                Text(loading ? "Reading logs\u{2026}" : "No entries in the last \(hours)h")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry)
                            .background(index.isMultiple(of: 2) ? Color.clear : rowTint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func row(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.time)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 64, alignment: .leading)

            Text(entry.category)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(tint(entry.category).opacity(0.16)))
                .foregroundStyle(tint(entry.category))
                .frame(width: 78, alignment: .leading)

            Text(entry.message)
                .font(.system(size: 11))
                .foregroundStyle(entry.isError ? Color.red : .primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $hours) {
                ForEach(ranges, id: \.self) { Text("\($0)h").tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .onChange(of: hours) { _, _ in load() }

            if loading { ProgressView().controlSize(.small) }
            Text("\(entries.count) entries")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let savedName {
                Label(savedName, systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(action: copy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .help("Copy all entries")
            Button(action: save) {
                Label("Save\u{2026}", systemImage: "square.and.arrow.down")
            }
            .help("Save to a file")
            Button(action: load) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Reload logs")
        }
        .padding(10)
    }

    private var rowTint: Color { Color.primary.opacity(0.04) }

    private func tint(_ category: String) -> Color {
        switch category {
        case "sync": return .blue
        case "gh": return .purple
        case "watch": return .teal
        case "onboard": return .indigo
        case "crypto": return .green
        default: return .gray
        }
    }

    private func load() {
        loading = true
        savedName = nil
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
        NSPasteboard.general.setString(Diagnostics.plainText(entries), forType: .string)
    }

    private func save() {
        guard let url = Diagnostics.save(Diagnostics.plainText(entries)) else { return }
        savedName = url.lastPathComponent
    }
}
