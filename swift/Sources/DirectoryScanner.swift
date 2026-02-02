import Foundation

/// Scans directories and builds a FileNode tree.
///
/// This scanner performs recursive directory traversal while respecting
/// common ignore patterns (node_modules, .git, etc.).
final class DirectoryScanner {
    private let fileManager = FileManager.default
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
    /// - Parameters:
    ///   - path: The absolute path to scan.
    ///   - maxDepth: Maximum recursion depth (default: 10).
    ///   - progress: Optional callback reporting item count during scan.
    /// - Returns: A `FileNode` tree, or `nil` if the path is invalid.
    @MainActor
    func scan(path: String, maxDepth: Int = 10, progress: ((Int) -> Void)? = nil) -> FileNode? {
        let url = URL(fileURLWithPath: path)
        var itemCount = 0
        let shouldUseIgnore = useIgnorePatterns
        
        func shouldIgnore(_ name: String) -> Bool {
            guard shouldUseIgnore else { return false }
            if Self.ignoredNames.contains(name) { return true }
            for suffix in Self.ignoredSuffixes where name.hasSuffix(suffix) {
                return true
            }
            return false
        }
        
        func scanDirectory(_ url: URL, depth: Int) -> FileNode? {
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
            
            itemCount += 1
            if itemCount % 100 == 0 {
                progress?(itemCount)
            }
            
            if isDirectory.boolValue {
                // Directory
                var children: [FileNode] = []
                
                if depth < maxDepth {
                    // Don't skip hidden files - include everything except ignored patterns
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
                
                let node = FileNode(
                    name: name,
                    path: path,
                    isDirectory: true,
                    children: children
                )
                _ = node.calculateSize()
                return node
            } else {
                // File - get size
                var size: Int64 = 0
                if let attrs = try? fileManager.attributesOfItem(atPath: path),
                   let fileSize = attrs[.size] as? Int64 {
                    size = fileSize
                }
                
                return FileNode(
                    name: name,
                    path: path,
                    isDirectory: false,
                    size: size
                )
            }
        }
        
        return scanDirectory(url, depth: 0)
    }
}
