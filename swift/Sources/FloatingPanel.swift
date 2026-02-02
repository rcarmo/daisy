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
    private let scanner = DirectoryScanner()
    private var watcher: DirectoryWatcher?
    
    var watchPath: String = ""
    var maxDepth: Int = 10
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create floating panel
        panel = FloatingPanel(contentRect: WindowConfig.defaultSize, viewModel: viewModel)
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        
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
        let resolvedPath = (path as NSString).expandingTildeInPath
        watchPath = resolvedPath
        
        print("🌼 Daisy - Watching: \(resolvedPath)")
        
        // Initial scan
        performScan()
        
        // Set up watcher
        watcher = DirectoryWatcher(path: resolvedPath) { [weak self] in
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
        viewModel.setScanning()
        
        let path = watchPath
        let depth = maxDepth
        
        Task.detached(priority: .userInitiated) { [scanner] in
            if let tree = await scanner.scan(path: path, maxDepth: depth) {
                await MainActor.run { [weak self] in
                    self?.viewModel.update(root: tree)
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
