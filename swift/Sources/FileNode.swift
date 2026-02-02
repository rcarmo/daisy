import Foundation

/// Represents a file or directory in the tree.
///
/// This class is marked as `@MainActor` to ensure thread-safe UI updates
/// when used with SwiftUI's `@ObservedObject`.
@MainActor
final class FileNode: Identifiable, ObservableObject {
    nonisolated let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    @Published private(set) var size: Int64
    @Published private(set) var children: [FileNode]
    
    /// Creates a new file node.
    /// - Parameters:
    ///   - name: The file or directory name.
    ///   - path: The absolute path.
    ///   - isDirectory: Whether this node represents a directory.
    ///   - size: The size in bytes (default: 0).
    ///   - children: Child nodes for directories (default: []).
    init(name: String, path: String, isDirectory: Bool, size: Int64 = 0, children: [FileNode] = []) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
    }
    
    /// Calculate total size including children.
    /// - Returns: The total size in bytes.
    @discardableResult
    func calculateSize() -> Int64 {
        if isDirectory {
            size = children.reduce(0) { $0 + $1.calculateSize() }
        }
        return size
    }
    
    /// Update children and recalculate size.
    /// - Parameter newChildren: The new child nodes.
    func updateChildren(_ newChildren: [FileNode]) {
        children = newChildren
        _ = calculateSize()
    }
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
