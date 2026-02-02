import AppKit
import Foundation

// MARK: - Constants

private enum AppInfo {
    static let name = "🌼 Daisy (Swift)"
    static let version = "0.1.0"
    static let description = "Disk Usage Sunburst Visualizer"
    static let defaultDepth = 10
}

// MARK: - CLI Interface

/// Print usage information.
private func printUsage() {
    let usage = """
    \(AppInfo.name) - \(AppInfo.description)
    
    Usage: daisy [options] <path>
    
    Options:
      -d, --depth <n>    Maximum directory depth (default: \(AppInfo.defaultDepth))
      --no-ignore        Disable default ignore patterns
      -h, --help         Show this help message
      -v, --version      Show version
    
    Examples:
      daisy .
      daisy ~/Documents
      daisy /var/log --depth 5
      daisy ~/Downloads --no-ignore
    """
    print(usage)
}

/// Print version.
private func printVersion() {
    print("\(AppInfo.name) v\(AppInfo.version)")
}

/// Parse command line arguments.
/// - Returns: A tuple of (path, depth, noIgnore) or nil if parsing failed.
private func parseArguments() -> (path: String, depth: Int, noIgnore: Bool)? {
    let args = Array(CommandLine.arguments.dropFirst())
    var path: String?
    var depth = AppInfo.defaultDepth
    var noIgnore = false
    var index = 0
    
    while index < args.count {
        let arg = args[index]
        
        switch arg {
        case "-h", "--help":
            printUsage()
            return nil
            
        case "-v", "--version":
            printVersion()
            return nil
            
        case "-d", "--depth":
            index += 1
            guard index < args.count, let d = Int(args[index]) else {
                print("Error: --depth requires a number")
                return nil
            }
            depth = d
            
        case "--no-ignore":
            noIgnore = true
            
        default:
            if arg.hasPrefix("-") {
                print("Unknown option: \(arg)")
                printUsage()
                return nil
            }
            path = arg
        }
        
        index += 1
    }
    
    guard let watchPath = path else {
        print("Error: No path specified")
        printUsage()
        return nil
    }
    
    // Resolve path
    let resolved = (watchPath as NSString).expandingTildeInPath
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue else {
        print("Error: '\(watchPath)' is not a valid directory")
        return nil
    }
    
    return (resolved, depth, noIgnore)
}

// MARK: - Entry Point

// Main entry point
guard let (path, depth, noIgnore) = parseArguments() else {
    exit(1)
}

// Store config for AppDelegate to access during launch
enum LaunchConfig {
    nonisolated(unsafe) static var watchPath: String = ""
    nonisolated(unsafe) static var maxDepth: Int = 10
    nonisolated(unsafe) static var noIgnore: Bool = false
}

LaunchConfig.watchPath = path
LaunchConfig.maxDepth = depth
LaunchConfig.noIgnore = noIgnore

// Start the app - delegate will be created by NSApplication on main thread
let app = NSApplication.shared

// Schedule delegate creation on main run loop before app.run() processes events
DispatchQueue.main.async {
    let delegate = AppDelegate()
    delegate.watchPath = LaunchConfig.watchPath
    delegate.maxDepth = LaunchConfig.maxDepth
    delegate.noIgnore = LaunchConfig.noIgnore
    app.delegate = delegate
    
    // Manually trigger applicationDidFinishLaunching since we set delegate late
    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
}

app.run()
