import Foundation

/// Scans directories and builds a FileNode tree.
///
/// This scanner performs recursive directory traversal while respecting
/// common ignore patterns (node_modules, .git, etc.).
///
/// Progress is reported via Foundation's `Progress` class, which supports
/// hierarchical progress tracking.
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
    /// Progress is reported via Foundation's `Progress` class. The caller can
    /// observe `Progress.current()` or pass a parent progress to track scanning.
    ///
    /// - Parameters:
    ///   - path: The absolute path to scan.
    ///   - maxDepth: Maximum recursion depth (default: 10).
    ///   - parentProgress: Optional parent Progress for hierarchical tracking.
    /// - Returns: A `FileNode` tree, or `nil` if the path is invalid.
    @MainActor
    func scan(path: String, maxDepth: Int = 10, parentProgress: Progress? = nil) -> FileNode? {
        let url = URL(fileURLWithPath: path)
        let shouldUseIgnore = useIgnorePatterns
        
        // Create a progress object for this scan
        // Using indeterminate since we don't know total count upfront
        let progress = Progress(totalUnitCount: -1)
        progress.kind = .file
        progress.localizedDescription = "Scanning..."
        
        // If we have a parent, become a child of it
        if let parent = parentProgress {
            parent.addChild(progress, withPendingUnitCount: 1)
        }
        
        func shouldIgnore(_ name: String) -> Bool {
            guard shouldUseIgnore else { return false }
            if Self.ignoredNames.contains(name) { return true }
            for suffix in Self.ignoredSuffixes where name.hasSuffix(suffix) {
                return true
            }
            return false
        }
        
        func scanDirectory(_ url: URL, depth: Int, currentProgress: Progress) -> FileNode? {
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
            
            // Update progress
            currentProgress.completedUnitCount += 1
            currentProgress.localizedDescription = "Scanning: \(name)"
            
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
                        // Create child progress for this directory's contents
                        let dirProgress = Progress(totalUnitCount: Int64(contents.count))
                        currentProgress.addChild(dirProgress, withPendingUnitCount: 0)
                        
                        for childURL in contents {
                            if let child = scanDirectory(childURL, depth: depth + 1, currentProgress: dirProgress) {
                                children.append(child)
                            }
                            dirProgress.completedUnitCount += 1
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
        
        return scanDirectory(url, depth: 0, currentProgress: progress)
    }
}
