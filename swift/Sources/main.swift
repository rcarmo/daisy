import AppKit
import Foundation

// MARK: - Constants

private enum AppInfo {
    static let name = "🌼 Daisy (Swift)"
    static let version = "0.1.0"
    static let description = "Disk Usage Sunburst Visualizer"
    static let defaultDepth = 10
    static let defaultProgressEvery = 250
}

// MARK: - CLI Interface

/// Print usage information.
private func printUsage() {
    let usage = """
    \(AppInfo.name) - \(AppInfo.description)
    
    Usage: daisy [options] <path>
    
    Options:
      -d, --depth <n>    Maximum directory depth (default: \(AppInfo.defaultDepth))
            --progress-every <n>
                                                 Emit UI updates every N items (default: \(AppInfo.defaultProgressEvery))
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
/// - Returns: A tuple of (path, depth, noIgnore, progressEvery) or nil if parsing failed.
private func parseArguments() -> (path: String, depth: Int, noIgnore: Bool, progressEvery: Int)? {
    let args = Array(CommandLine.arguments.dropFirst())
    var path: String?
    var depth = AppInfo.defaultDepth
    var noIgnore = false
    var progressEvery = AppInfo.defaultProgressEvery
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

        case "--progress-every":
            index += 1
            guard index < args.count, let v = Int(args[index]), v > 0 else {
                print("Error: --progress-every requires a positive number")
                return nil
            }
            progressEvery = v
            
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
    
    return (resolved, depth, noIgnore, progressEvery)
}

// MARK: - Entry Point

guard let (path, depth, noIgnore, progressEvery) = parseArguments() else {
    exit(1)
}

let app = NSApplication.shared

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    delegate.watchPath = path
    delegate.maxDepth = depth
    delegate.noIgnore = noIgnore
    delegate.progressEvery = progressEvery
    app.delegate = delegate
}

app.run()
