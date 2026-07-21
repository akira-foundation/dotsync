import DotSyncCore
import SwiftUI

struct RootDetail: Equatable {
    var pending: [String]
    var history: [HistoryEntry]
}

struct RootDetailView: View {
    let detail: RootDetail

    private let pendingLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if detail.pending.isEmpty {
                Label("Nothing pending", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                sectionTitle("Pending (\(detail.pending.count))")
                ForEach(detail.pending.prefix(pendingLimit), id: \.self) { path in
                    Text(path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if detail.pending.count > pendingLimit {
                    Text("+\(detail.pending.count - pendingLimit) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !detail.history.isEmpty {
                sectionTitle("Recent")
                ForEach(detail.history) { entry in
                    HStack(spacing: 6) {
                        Text(relative(entry.timestamp))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 62, alignment: .leading)
                        Text(entry.subject)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.bottom, 9)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private func relative(_ timestamp: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: timestamp) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
