import Foundation

/// Lightweight scan result (not MainActor-bound).
/// Used during scanning, then converted to FileNode for UI.
struct ScanNode: Sendable {
    let name: String
    let path: String
    let isDirectory: Bool
    var size: Int64
    var children: [ScanNode]
    
    /// Calculate total size recursively.
    mutating func calculateSize() -> Int64 {
        if isDirectory {
            size = children.reduce(0) { total, child in
                var mutableChild = child
                return total + mutableChild.calculateSize()
            }
        }
        return size
    }
}

/// Scans directories and builds a FileNode tree.
///
/// This scanner performs recursive directory traversal while respecting
/// common ignore patterns (node_modules, .git, etc.).
///
/// Scanning happens off the main thread, then results are converted to
/// FileNode on MainActor for UI display.
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
    
    /// Scan a directory and return a FileNode tree.
    ///
    /// Scanning runs on a background thread. Only the final conversion
    /// to FileNode happens on MainActor.
    ///
    /// - Parameters:
    ///   - path: The absolute path to scan.
    ///   - maxDepth: Maximum recursion depth (default: 10).
    /// - Returns: A `FileNode` tree, or `nil` if the path is invalid.
    func scan(path: String, maxDepth: Int = 10) async -> FileNode? {
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
        
        func scanDirectory(_ url: URL, depth: Int) -> ScanNode? {
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
                var children: [ScanNode] = []
                
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
                children.sort { $0.size > $1.size }
                
                var node = ScanNode(
                    name: name,
                    path: path,
                    isDirectory: true,
                    size: 0,
                    children: children
                )
                _ = node.calculateSize()
                return node
            } else {
                var size: Int64 = 0
                if let attrs = try? fileManager.attributesOfItem(atPath: path),
                   let fileSize = attrs[.size] as? Int64 {
                    size = fileSize
                }
                
                return ScanNode(
                    name: name,
                    path: path,
                    isDirectory: false,
                    size: size,
                    children: []
                )
            }
        }
        
        // Scan on current (background) thread
        guard var scanResult = scanDirectory(url, depth: 0) else {
            return nil
        }
        _ = scanResult.calculateSize()
        
        // Capture as let for Sendable compliance
        let finalResult = scanResult
        
        // Convert to FileNode on MainActor
        return await MainActor.run {
            convertToFileNode(finalResult)
        }
    }
    
    /// Convert ScanNode tree to FileNode tree (must be called on MainActor).
    @MainActor
    private func convertToFileNode(_ scan: ScanNode) -> FileNode {
        let children = scan.children.map { convertToFileNode($0) }
        return FileNode(
            name: scan.name,
            path: scan.path,
            isDirectory: scan.isDirectory,
            size: scan.size,
            children: children
        )
    }
}
