import Foundation

/// Watches a directory for changes using FSEvents.
///
/// This watcher uses macOS FSEvents API to monitor file system changes
/// with debouncing to avoid rapid-fire callbacks.
final class DirectoryWatcher {
    // MARK: - Properties
    
    private var stream: FSEventStreamRef?
    private let path: String
    private let callback: @Sendable () -> Void
    private let debounceInterval: TimeInterval
    private var pendingWork: DispatchWorkItem?
    
    /// Creates a new directory watcher.
    /// - Parameters:
    ///   - path: The absolute path to watch.
    ///   - debounceInterval: Time to wait before triggering callback (default: 0.5s).
    ///   - callback: Closure called when changes are detected.
    init(path: String, debounceInterval: TimeInterval = 0.5, callback: @escaping @Sendable () -> Void) {
        self.path = path
        self.debounceInterval = debounceInterval
        self.callback = callback
    }
    
    deinit {
        stop()
    }
    
    /// Start watching for file system changes.
    func start() {
        guard stream == nil else { return } // Prevent double-start
        
        let pathsToWatch = [path] as CFArray
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        // Flags for file-level events and recursive watching
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagWatchRoot
        )
        
        print("🔧 FSEvents: Creating stream for path: \(path)")
        
        stream = FSEventStreamCreate(
            nil,
            { _, info, numEvents, eventPaths, eventFlags, _ in
                guard let info else { return }
                let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
                
                // Log event details for debugging
                if let paths = eventPaths as? [String] {
                    for (i, p) in paths.prefix(3).enumerated() {
                        print("📁 Event[\(i)]: \(p)")
                    }
                    if paths.count > 3 {
                        print("📁 ... and \(paths.count - 3) more events")
                    }
                }
                
                watcher.handleEvents(count: numEvents)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // latency
            flags
        )
        
        if let stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            let started = FSEventStreamStart(stream)
            print("🔧 FSEvents: Stream started = \(started)")
        } else {
            print("❌ FSEvents: Failed to create stream!")
        }
    }
    
    /// Stop watching for file system changes.
    func stop() {
        pendingWork?.cancel()
        pendingWork = nil
        
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
    
    private func handleEvents(count: Int) {
        // Debounce rapid events
        pendingWork?.cancel()
        
        print("📡 FSEvents received: \(count) events")
        
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            print("⚡ Debounce complete, triggering callback")
            self.callback()
        }
        
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
