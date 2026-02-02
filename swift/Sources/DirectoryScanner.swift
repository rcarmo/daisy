import Foundation

/// Scans directories and builds a DataNode tree.
///
/// This scanner performs recursive directory traversal while respecting
/// common ignore patterns (node_modules, .git, etc.).
///
/// Scanning happens off the main thread, returning immutable `DataNode`
/// values that can be assigned directly on MainActor for UI display.
final class DirectoryScanner: Sendable {
    private let useIgnorePatterns: Bool
    
    /// File and directory names to ignore during scanning.
    private static let ignoredNames: Set<String> = [
        ".DS_Store", ".git", ".svn", ".Trash",
        "node_modules", "__pycache__", ".pytest_cache", ".mypy_cache",
        "coverage", "dist", ".next", ".turbo"
    ]
    
    /// File suffixes to ignore (e.g., swap files).
    private static let ignoredSuffixes: [String] = [".swp", ".swo"]
    
    /// Creates a new directory scanner.
    /// - Parameter ignorePatterns: If true, disables default ignore patterns.
    init(ignorePatterns: Bool = false) {
        self.useIgnorePatterns = !ignorePatterns
    }
    
    /// Scan a directory and return a DataNode tree.
    ///
    /// Scanning runs on a background thread, returning immutable
    /// `Sendable` data safe to pass across actors.
    ///
    /// - Parameters:
    ///   - path: The absolute path to scan.
    ///   - maxDepth: Maximum recursion depth (default: 10).
    /// - Returns: A `DataNode` tree, or `nil` if the path is invalid.
    func scan(path: String, maxDepth: Int = 10) async -> DataNode? {
        let url = URL(fileURLWithPath: path)
        let shouldUseIgnore = useIgnorePatterns
        let fileManager = FileManager()
        
        func shouldIgnore(_ name: String) -> Bool {
            guard shouldUseIgnore else { return false }
            if Self.ignoredNames.contains(name) { return true }
            for suffix in Self.ignoredSuffixes where name.hasSuffix(suffix) {
                return true
            }
            return false
        }
        
        func scanDirectory(_ url: URL, depth: Int) -> DataNode? {
            let name = url.lastPathComponent
            let path = url.path
            
            // Skip ignored items
            if shouldIgnore(name) {
                return nil
            }
            
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                return nil
            }
            
            if isDirectory.boolValue {
                var children: [DataNode] = []
                
                if depth < maxDepth {
                    if let contents = try? fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                        options: []
                    ) {
                        for childURL in contents {
                            if let child = scanDirectory(childURL, depth: depth + 1) {
                                children.append(child)
                            }
                        }
                    }
                }
                
                // Sort children by size (descending)
                let sortedChildren = children.sorted { $0.size > $1.size }
                let totalSize = sortedChildren.reduce(0) { $0 + $1.size }
                return DataNode(
                    id: path,
                    name: name,
                    path: path,
                    isDirectory: true,
                    size: totalSize,
                    children: sortedChildren
                )
            } else {
                var size: Int64 = 0
                if let attrs = try? fileManager.attributesOfItem(atPath: path),
                   let fileSize = attrs[.size] as? Int64 {
                    size = fileSize
                }

                return DataNode(
                    id: path,
                    name: name,
                    path: path,
                    isDirectory: false,
                    size: size,
                    children: []
                )
            }
        }

        // Scan on current (background) thread
        return scanDirectory(url, depth: 0)
    }
}
