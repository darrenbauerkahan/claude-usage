import Foundation
import os.log

private let logger = Logger(subsystem: Constants.App.bundleIdentifier, category: "HistoryStore")

/// A single timestamped usage snapshot persisted to disk.
struct HistorySnapshot: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionUtilization: Int   // five_hour utilization (0-100+)
    let weeklyUtilization: Int    // seven_day utilization (0-100+)
}

/// Persists usage snapshots as JSON in Application Support.
/// Thread-safe via @MainActor isolation.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var snapshots: [HistorySnapshot] = []

    private let fileURL: URL
    private static let retentionDays: Double = 8
    private var hasSetPermissions = false

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent(Constants.App.bundleIdentifier)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("usage_history.json")
        load()
        logger.debug("HistoryStore initialized, loaded \(self.snapshots.count) snapshots")
    }

    /// Saves a new snapshot and prunes entries older than 8 days.
    /// Skips saving if values are unchanged from the last snapshot.
    func saveSnapshot(session: Int, weekly: Int) {
        // Deduplicate: skip if values unchanged from last snapshot
        if let last = snapshots.last,
           last.sessionUtilization == session,
           last.weeklyUtilization == weekly {
            return
        }

        let snapshot = HistorySnapshot(
            id: UUID(),
            timestamp: Date(),
            sessionUtilization: session,
            weeklyUtilization: weekly
        )
        snapshots.append(snapshot)
        prune()
        persist()
        logger.debug("Saved snapshot: session=\(session)%, weekly=\(weekly)%, total=\(self.snapshots.count)")
    }

    /// Returns snapshots with timestamp >= the given date.
    func snapshots(since date: Date) -> [HistorySnapshot] {
        snapshots.filter { $0.timestamp >= date }
    }

    // MARK: - Private

    private func prune() {
        let cutoff = Date().addingTimeInterval(
            -Self.retentionDays * Double(Constants.Time.secondsPerDay)
        )
        let before = snapshots.count
        snapshots.removeAll { $0.timestamp < cutoff }
        if snapshots.count < before {
            logger.debug("Pruned \(before - self.snapshots.count) old snapshots")
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(snapshots)
            let isNewFile = !FileManager.default.fileExists(atPath: fileURL.path)
            try data.write(to: fileURL, options: .atomic)
            // Only set permissions on first write; atomic write preserves them after
            if isNewFile || !hasSetPermissions {
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: fileURL.path
                )
                hasSetPermissions = true
            }
        } catch {
            logger.error("Failed to persist history: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([HistorySnapshot].self, from: data)
            let cutoff = Date().addingTimeInterval(
                -Self.retentionDays * Double(Constants.Time.secondsPerDay)
            )
            snapshots = decoded.filter { $0.timestamp >= cutoff }
        } catch {
            logger.warning("Failed to load history: \(error.localizedDescription)")
        }
    }
}
