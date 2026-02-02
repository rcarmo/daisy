import AppKit
import SwiftUI

// MARK: - Constants

private enum WindowConfig {
    static let backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1)
    static let minSize = NSSize(width: 300, height: 300)
    static let defaultSize = NSRect(x: 100, y: 100, width: 500, height: 500)
}

// MARK: - Floating Panel

/// A floating panel window for the sunburst visualization.
///
/// This panel stays above other windows and is movable by dragging
/// anywhere on the background.
final class FloatingPanel: NSPanel {
    /// Creates a new floating panel with the sunburst view.
    /// - Parameters:
    ///   - contentRect: The initial frame rectangle.
    ///   - viewModel: The view model to bind to the sunburst view.
    init(contentRect: NSRect, viewModel: SunburstViewModel) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configurePanel()
        
        // Set content view
        let hostingView = NSHostingView(rootView: SunburstView(viewModel: viewModel))
        self.contentView = hostingView
    }
    
    private func configurePanel() {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = WindowConfig.backgroundColor
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        minSize = WindowConfig.minSize
        title = "🌼 Daisy"
    }
}

// MARK: - App Delegate

/// App delegate that manages the floating window and file scanning.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    private(set) var panel: FloatingPanel?
    private let viewModel = SunburstViewModel()
    private var scanner: DirectoryScanner?
    private var watcher: DirectoryWatcher?
    private var scanGeneration: Int = 0
    
    var watchPath: String = ""
    var maxDepth: Int = 10
    var noIgnore: Bool = false
    var progressEvery: Int = 250
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create floating panel
        panel = FloatingPanel(contentRect: WindowConfig.defaultSize, viewModel: viewModel)
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)

        viewModel.onRescan = { [weak self] in
            self?.performScan()
        }
        
        // Start scanning if path was set
        if !watchPath.isEmpty {
            startWatching(path: watchPath)
        }
        
        // Hide dock icon (agent app style)
        NSApp.setActivationPolicy(.accessory)
    }
    
    // MARK: - Scanning
    
    /// Start watching a directory for changes.
    /// - Parameter path: The absolute path to watch.
    func startWatching(path: String) {
        // Resolve to absolute path (handles ~, .., relative paths)
        let expandedPath = (path as NSString).expandingTildeInPath
        let absolutePath = (expandedPath as NSString).standardizingPath
        let resolvedPath: String
        
        if absolutePath.hasPrefix("/") {
            resolvedPath = absolutePath
        } else {
            // Relative path - resolve from current directory
            resolvedPath = FileManager.default.currentDirectoryPath + "/" + absolutePath
        }
        
        // Normalize the path (resolve ../ etc)
        let url = URL(fileURLWithPath: resolvedPath).standardized
        watchPath = url.path
        
        // Create scanner with ignore setting
        scanner = DirectoryScanner(ignorePatterns: noIgnore)
        
        print("🌼 Daisy - Watching: \(watchPath)\(noIgnore ? " (no ignore)" : "")")
        
        // Initial scan
        performScan()
        
        // Set up watcher with ABSOLUTE path (required for FSEvents)
        watcher = DirectoryWatcher(path: watchPath) { [weak self] in
            print("📁 Change detected, rescanning...")
            Task { @MainActor in
                self?.performScan()
            }
        }
        watcher?.start()
        print("👀 Watching for changes...")
    }
    
    /// Perform a directory scan and update the view.
    func performScan() {
        guard let scanner else { return }
        
        viewModel.setScanning()
        
        let path = watchPath
        let depth = maxDepth
        let updateEvery = progressEvery
        scanGeneration += 1
        let currentGeneration = scanGeneration
        
        Task.detached(priority: .userInitiated) { [scanner] in
            if let tree = await scanner.scanProgressive(
                path: path,
                maxDepth: depth,
                updateEvery: updateEvery,
                progress: { snapshot in
                    await MainActor.run { [weak self] in
                        guard let self, self.scanGeneration == currentGeneration else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.viewModel.updateSnapshot(root: snapshot)
                        }
                    }
                }
            ) {
                await MainActor.run { [weak self] in
                    guard let self, self.scanGeneration == currentGeneration else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.viewModel.updateFinal(root: tree)
                    }
                    print("📊 Scanned \(path): \(formatBytes(tree.size))")
                }
            }
        }
    }
    
    // MARK: - NSApplicationDelegate
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        watcher?.stop()
        print("👋 Shutting down...")
    }
}
