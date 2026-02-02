import SwiftUI

// MARK: - Configuration

/// Configuration constants for the sunburst chart.
enum SunburstConfig {
    static let innerRadius: CGFloat = 50
    static let maxDepth: Int = 6
    static let minAngleForDisplay: Double = 0.5 // degrees
}

// MARK: - Color Constants

private extension Color {
    static let backgroundDark = Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1))
    static let panelBackground = Color(nsColor: NSColor(red: 0.19, green: 0.19, blue: 0.27, alpha: 0.9))
    static let accentBlue = Color(nsColor: NSColor(red: 0.54, green: 0.71, blue: 0.98, alpha: 1))
    static let successGreen = Color(nsColor: NSColor(red: 0.65, green: 0.89, blue: 0.63, alpha: 1))
}

// MARK: - Sunburst View

/// Sunburst chart view using SwiftUI Canvas for efficient rendering.
struct SunburstView: View {
    @ObservedObject var viewModel: SunburstViewModel
    @State private var hoveredNode: DataNode?
    @State private var mouseLocation: CGPoint = .zero
    @State private var isHovering: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = size / 2 - 10
            let ringWidth = (maxRadius - SunburstConfig.innerRadius) / CGFloat(SunburstConfig.maxDepth)
            
            ZStack {
                Color.backgroundDark
                
                if let root = viewModel.viewRoot {
                    sunburstCanvas(root: root, center: center, ringWidth: ringWidth)
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                mouseLocation = location
                                let newHovered = hitTest(
                                    location: location,
                                    root: root,
                                    center: center,
                                    ringWidth: ringWidth
                                )
                                if newHovered?.path != hoveredNode?.path {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        hoveredNode = newHovered
                                        isHovering = newHovered != nil
                                    }
                                }
                            case .ended:
                                withAnimation(.easeOut(duration: 0.2)) {
                                    hoveredNode = nil
                                    isHovering = false
                                }
                            }
                        }
                        .onTapGesture { location in
                            if let node = hitTest(
                                location: location,
                                root: root,
                                center: center,
                                ringWidth: ringWidth
                            ), node.isDirectory {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.zoomTo(node)
                                }
                            }
                        }
                    
                    centerLabel(root: root, center: center)
                }
                
                // Hover tooltip
                if let node = hoveredNode {
                    hoverTooltip(for: node)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                infoPanel
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.viewRoot?.path)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func sunburstCanvas(root: DataNode, center: CGPoint, ringWidth: CGFloat) -> some View {
        Canvas { context, _ in
            drawNode(
                context: context,
                node: root,
                center: center,
                startAngle: 0,
                endAngle: 360,
                depth: 1,
                ringWidth: ringWidth
            )
        }
    }
    
    @ViewBuilder
    private func centerLabel(root: DataNode, center: CGPoint) -> some View {
        VStack(spacing: 2) {
            Text(formatBytes(root.size))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(root.name)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(width: SunburstConfig.innerRadius * 1.8, height: SunburstConfig.innerRadius * 1.8)
        .background(Color.backgroundDark)
        .clipShape(Circle())
        .scaleEffect(viewModel.zoomStack.count > 1 ? 1.0 : 0.95)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
        .position(center)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.zoomOut()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: root.size)
    }
    
    @ViewBuilder
    private func hoverTooltip(for node: DataNode) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(node.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(formatBytes(node.size))
                .font(.system(size: 10))
                .foregroundColor(.accentBlue)
            if node.isDirectory {
                Text("\(node.children.count) items")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.panelBackground)
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .position(
            x: min(max(mouseLocation.x + 60, 80), NSScreen.main?.frame.width ?? 500 - 80),
            y: max(mouseLocation.y - 30, 40)
        )
        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: mouseLocation)
    }
    
    @ViewBuilder
    private var infoPanel: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Spacer()
            if let root = viewModel.root {
                HStack(spacing: 8) {
                    Text(formatBytes(root.size))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentBlue)
                        .contentTransition(.numericText())
                    Text(root.path)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    Text(viewModel.status)
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.statusColor)
                        .id(viewModel.status)  // Force re-render for animation
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.panelBackground)
                .cornerRadius(6)
                .animation(.easeInOut(duration: 0.2), value: viewModel.status)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
    
    private func drawNode(
        context: GraphicsContext,
        node: DataNode,
        center: CGPoint,
        startAngle: Double,
        endAngle: Double,
        depth: Int,
        ringWidth: CGFloat
    ) {
        guard depth <= SunburstConfig.maxDepth else { return }
        guard !node.children.isEmpty else { return }
        
        let innerR = SunburstConfig.innerRadius + CGFloat(depth - 1) * ringWidth
        let outerR = SunburstConfig.innerRadius + CGFloat(depth) * ringWidth
        
        var currentAngle = startAngle
        let angleRange = endAngle - startAngle
        
        for child in node.children {
            guard child.size > 0 else { continue }
            
            let childAngle = (Double(child.size) / Double(node.size)) * angleRange
            let childEndAngle = currentAngle + childAngle
            
            // Skip tiny segments
            guard childAngle >= SunburstConfig.minAngleForDisplay else {
                currentAngle = childEndAngle
                continue
            }
            
            // Draw arc
            let path = createArcPath(
                center: center,
                innerRadius: innerR,
                outerRadius: outerR,
                startAngle: currentAngle,
                endAngle: childEndAngle
            )
            
            let color = getColor(
                startAngle: currentAngle,
                depth: depth,
                isChanged: viewModel.changedPaths.contains(child.path),
                isRemoved: viewModel.removedHighlightPaths.contains(child.path),
                isAdded: viewModel.addedHighlightPaths.contains(child.path)
            )
            context.fill(path, with: .color(color))
            context.stroke(path, with: .color(Color.backgroundDark), lineWidth: 1)
            
            // Recursively draw children
            if child.isDirectory {
                drawNode(
                    context: context,
                    node: child,
                    center: center,
                    startAngle: currentAngle,
                    endAngle: childEndAngle,
                    depth: depth + 1,
                    ringWidth: ringWidth
                )
            }
            
            currentAngle = childEndAngle
        }
    }
    
    private func createArcPath(
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        startAngle: Double,
        endAngle: Double
    ) -> Path {
        var path = Path()
        
        let startRad = Angle(degrees: startAngle - 90).radians
        let endRad = Angle(degrees: endAngle - 90).radians
        
        // Outer arc
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: Angle(radians: startRad),
            endAngle: Angle(radians: endRad),
            clockwise: false
        )
        
        // Line to inner arc
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: Angle(radians: endRad),
            endAngle: Angle(radians: startRad),
            clockwise: true
        )
        
        path.closeSubpath()
        return path
    }
    
    private func getColor(startAngle: Double, depth: Int, isChanged: Bool, isRemoved: Bool, isAdded: Bool) -> Color {
        let hue = startAngle / 360.0
        
        // Convert from HSL (used in Bun) to approximate HSB values
        // Bun uses: saturation 70-30%, lightness 45-70%
        // For HSB: higher saturation and brightness for vivid colors
        let saturation: Double
        let brightness: Double
        
        if isRemoved {
            saturation = 0.85
            brightness = 0.85
        } else if isAdded {
            saturation = 0.85
            brightness = 0.98
        } else if isChanged {
            saturation = 0.85
            brightness = 0.95
        } else {
            // Match Bun's HSL appearance with HSB
            // Outer rings (depth 1): more saturated, brighter
            // Inner rings (higher depth): less saturated, slightly less bright
            saturation = max(0.50, 0.80 - Double(depth) * 0.05)
            brightness = min(0.95, 0.75 + Double(depth) * 0.03)
        }
        
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    // MARK: - Hit Testing
    
    /// Find which node is under the given point.
    private func hitTest(
        location: CGPoint,
        root: DataNode,
        center: CGPoint,
        ringWidth: CGFloat
    ) -> DataNode? {
        // Convert to polar coordinates
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Check if inside the chart area
        let maxRadius = SunburstConfig.innerRadius + CGFloat(SunburstConfig.maxDepth) * ringWidth
        guard distance >= SunburstConfig.innerRadius && distance <= maxRadius else {
            return nil
        }
        
        // Calculate angle (0-360, starting from top)
        var angle = atan2(dx, -dy) * 180 / .pi
        if angle < 0 { angle += 360 }
        
        // Calculate depth from distance
        let depth = Int((distance - SunburstConfig.innerRadius) / ringWidth) + 1
        
        // Search for the node at this angle and depth
        return findNodeAt(
            angle: angle,
            targetDepth: depth,
            node: root,
            startAngle: 0,
            endAngle: 360,
            currentDepth: 1
        )
    }
    
    /// Recursively find the node at a given angle and depth.
    private func findNodeAt(
        angle: Double,
        targetDepth: Int,
        node: DataNode,
        startAngle: Double,
        endAngle: Double,
        currentDepth: Int
    ) -> DataNode? {
        guard currentDepth <= SunburstConfig.maxDepth else { return nil }
        guard !node.children.isEmpty else { return nil }
        
        var currentAngle = startAngle
        let angleRange = endAngle - startAngle
        
        for child in node.children {
            guard child.size > 0 else { continue }
            
            let childAngle = (Double(child.size) / Double(node.size)) * angleRange
            let childEndAngle = currentAngle + childAngle
            
            // Skip tiny segments
            guard childAngle >= SunburstConfig.minAngleForDisplay else {
                currentAngle = childEndAngle
                continue
            }
            
            // Check if angle is in this segment
            if angle >= currentAngle && angle < childEndAngle {
                // Found the segment at this depth
                if currentDepth == targetDepth {
                    return child
                }
                // Need to go deeper
                if child.isDirectory {
                    return findNodeAt(
                        angle: angle,
                        targetDepth: targetDepth,
                        node: child,
                        startAngle: currentAngle,
                        endAngle: childEndAngle,
                        currentDepth: currentDepth + 1
                    )
                }
                return nil
            }
            
            currentAngle = childEndAngle
        }
        
        return nil
    }
}

// MARK: - View Model

/// View model for the sunburst chart.
///
/// Manages the file tree state, zoom navigation, and change tracking.
@MainActor
final class SunburstViewModel: ObservableObject {
    @Published private(set) var root: DataNode?
    @Published private(set) var viewRoot: DataNode?
    @Published private(set) var status: String = "⏳"
    @Published private(set) var statusColor: Color = .gray
    @Published private(set) var changedPaths: Set<String> = []
    @Published private(set) var removedPaths: Set<String> = []
    @Published private(set) var removedHighlightPaths: Set<String> = []
    @Published private(set) var addedHighlightPaths: Set<String> = []
    @Published private(set) var zoomStack: [DataNode] = []
    
    private var previousSizes: [String: Int64] = [:]
    
    // MARK: - Public Methods
    
    func updateFinal(root: DataNode) {
        // Track changes
        var newSizes: [String: Int64] = [:]
        var changed: Set<String> = []
        let previousPaths = Set(previousSizes.keys)
        
        func collectSizes(_ node: DataNode) {
            newSizes[node.path] = node.size
            if let oldSize = previousSizes[node.path], oldSize != node.size {
                changed.insert(node.path)
            } else if previousSizes[node.path] == nil && !previousSizes.isEmpty {
                changed.insert(node.path)
            }
            for child in node.children {
                collectSizes(child)
            }
        }
        collectSizes(root)

        let removed = previousPaths.subtracting(newSizes.keys)
        let added = previousSizes.isEmpty ? Set<String>() : Set(newSizes.keys).subtracting(previousPaths)
        let removedHighlights = buildRemovedHighlightPaths(removed, existingPaths: Set(newSizes.keys))
        let addedHighlights = buildAddedHighlightPaths(added)

        self.changedPaths = changed
        self.removedPaths = removed
        self.removedHighlightPaths = removedHighlights
        self.addedHighlightPaths = addedHighlights
        self.previousSizes = newSizes
        
        self.root = root
        
        // Preserve zoom if possible
        if let currentView = viewRoot,
           let newView = findNode(in: root, path: currentView.path) {
            viewRoot = newView
            zoomStack = zoomStack.compactMap { findNode(in: root, path: $0.path) }
        } else {
            viewRoot = root
            zoomStack = [root]
        }
        
        let removedLabel = removed.isEmpty ? "" : " −\(removed.count)"
        let addedLabel = added.isEmpty ? "" : " +\(added.count)"
        status = "✓\(addedLabel)\(removedLabel)"
        statusColor = .successGreen
        
        // Clear highlights after delay
        if !changed.isEmpty || !removedHighlights.isEmpty || !addedHighlights.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.changedPaths = []
                self?.removedHighlightPaths = []
                self?.addedHighlightPaths = []
            }
        }
    }

    func updateSnapshot(root: DataNode) {
        self.root = root

        if let currentView = viewRoot,
           let newView = findNode(in: root, path: currentView.path) {
            viewRoot = newView
            zoomStack = zoomStack.compactMap { findNode(in: root, path: $0.path) }
        } else {
            viewRoot = root
            zoomStack = [root]
        }
    }
    
    func setScanning() {
        status = "⏳"
        statusColor = .yellow
    }
    
    func zoomTo(_ node: DataNode) {
        guard node.isDirectory else { return }
        zoomStack.append(node)
        viewRoot = node
    }
    
    func zoomOut() {
        guard zoomStack.count > 1 else { return }
        zoomStack.removeLast()
        viewRoot = zoomStack.last
    }
    
    private func findNode(in root: DataNode, path: String) -> DataNode? {
        if root.path == path { return root }
        for child in root.children {
            if let found = findNode(in: child, path: path) {
                return found
            }
        }
        return nil
    }

    private func buildRemovedHighlightPaths(_ removed: Set<String>, existingPaths: Set<String>) -> Set<String> {
        guard !removed.isEmpty else { return [] }
        var highlights: Set<String> = []

        for removedPath in removed {
            var current = removedPath as NSString
            while true {
                let parent = current.deletingLastPathComponent
                if parent.isEmpty || parent == current as String {
                    break
                }
                if existingPaths.contains(parent) {
                    highlights.insert(parent)
                }
                current = parent as NSString
            }
        }

        return highlights
    }

    private func buildAddedHighlightPaths(_ added: Set<String>) -> Set<String> {
        guard !added.isEmpty else { return [] }
        return added
    }
}
