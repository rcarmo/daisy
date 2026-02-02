import Foundation

/// Represents a file or directory in the tree.
///
/// Immutable and `Sendable` so it can be built on background threads
/// and assigned directly to the ViewModel on `MainActor`.
struct DataNode: Sendable, Identifiable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let children: [DataNode]
}

// MARK: - Formatting

/// Shared ByteCountFormatter for consistent size formatting.
private let byteCountFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB, .usePB]
    formatter.countStyle = .file
    return formatter
}()

/// Format bytes to human-readable string using Foundation's ByteCountFormatter.
/// - Parameter bytes: The byte count to format.
/// - Returns: A human-readable string like "1.5 GB".
func formatBytes(_ bytes: Int64) -> String {
    byteCountFormatter.string(fromByteCount: bytes)
}
