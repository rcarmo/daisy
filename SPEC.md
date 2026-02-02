# Daisy - Live Disk Usage Sunburst Visualizer

A Bun CLI application that watches a folder and provides real-time disk usage visualization via a sunburst diagram using Server-Sent Events (SSE).

## Overview

**Daisy** monitors a specified directory, calculates disk usage hierarchically, and streams updates to connected web clients via SSE. The browser renders an interactive sunburst chart that updates live as files are added, removed, or modified.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   File System   │────▶│   Bun Server    │────▶│  Browser/SSE    │
│   (fs.watch)    │     │   + Scanner     │     │  + SVG Render   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Components

1. **CLI Entry Point** (`src/cli.ts`)
   - Parse arguments (path, port, depth, ignore patterns)
   - Initialize server and watcher

2. **Directory Scanner** (`src/scanner.ts`)
   - Recursive directory traversal
   - Size calculation with caching
   - Respects ignore patterns (`.gitignore`, custom)

3. **File Watcher** (`src/watcher.ts`)
   - Uses Bun's native `fs.watch` 
   - Debounces rapid changes
   - Triggers incremental or full rescans

4. **HTTP/SSE Server** (`src/server.ts`)
   - Serves static HTML/JS/CSS
   - SSE endpoint for real-time updates
   - REST endpoint for initial data fetch

5. **Sunburst Renderer** (`src/renderer.ts` + `public/sunburst.js`)
   - Server: Generate hierarchical JSON
   - Client: Render SVG sunburst

## Data Structures

### Directory Node

```typescript
interface DirNode {
  name: string;
  path: string;
  size: number;          // bytes
  isDirectory: boolean;
  children?: DirNode[];
  depth: number;
  color?: string;        // computed for visualization
}
```

### SSE Event Types

```typescript
type SSEEvent = 
  | { type: 'full'; data: DirNode }           // Full tree update
  | { type: 'delta'; data: DeltaUpdate }      // Incremental update
  | { type: 'error'; message: string }
  | { type: 'scanning'; progress: number };
```

### Delta Update (for efficiency)

```typescript
interface DeltaUpdate {
  added: { path: string; node: DirNode }[];
  removed: string[];      // paths
  modified: { path: string; size: number }[];
}
```

## CLI Interface

```bash
daisy [options] <path>

Options:
  -p, --port <number>     Server port (default: 3210)
  -d, --depth <number>    Max directory depth to scan (default: 10)
  -i, --ignore <pattern>  Ignore patterns (can be repeated)
  -o, --open              Open browser automatically
  -w, --watch             Enable file watching (default: true)
  --no-watch              Disable file watching
  -h, --help              Show help
  -v, --version           Show version

Examples:
  daisy .
  daisy ~/Documents --port 8080 --depth 5
  daisy /var/log -i "*.tmp" -i "node_modules"
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Serves the HTML viewer |
| `/api/tree` | GET | Returns current directory tree as JSON |
| `/api/events` | GET | SSE stream for real-time updates |
| `/api/info` | GET | Server info (watched path, settings) |

## SVG Rendering Strategy

We will use a **custom SVG rendering approach** on the client side for the following reasons:

1. **No external dependencies** - keeps bundle size minimal
2. **Full control** over rendering and animations
3. **Optimized for sunburst** - no unused code from general-purpose libraries
4. **Easy SSE integration** - direct DOM manipulation for updates

### Custom Sunburst Implementation

The sunburst is rendered using these SVG primitives:

```typescript
// Core rendering function
function renderSunburst(root: DirNode, options: SunburstOptions): SVGElement {
  // 1. Compute angles using partition layout
  // 2. Generate arc paths for each node
  // 3. Apply color scheme based on depth/type
  // 4. Add interactivity (hover, click-to-zoom)
}

interface SunburstOptions {
  width: number;
  height: number;
  innerRadius: number;      // center hole size
  maxDepth: number;         // rings to display
  colorScheme: 'rainbow' | 'categorical' | 'monochrome';
  showLabels: boolean;
  minAngleForLabel: number; // degrees
}
```

### Arc Path Generation

Each segment is an SVG `<path>` using arc commands:

```typescript
function describeArc(
  cx: number, cy: number,
  innerR: number, outerR: number,
  startAngle: number, endAngle: number
): string {
  const start1 = polarToCartesian(cx, cy, outerR, startAngle);
  const end1 = polarToCartesian(cx, cy, outerR, endAngle);
  const start2 = polarToCartesian(cx, cy, innerR, endAngle);
  const end2 = polarToCartesian(cx, cy, innerR, startAngle);
  
  const largeArc = endAngle - startAngle > 180 ? 1 : 0;
  
  return [
    `M ${start1.x} ${start1.y}`,
    `A ${outerR} ${outerR} 0 ${largeArc} 1 ${end1.x} ${end1.y}`,
    `L ${start2.x} ${start2.y}`,
    `A ${innerR} ${innerR} 0 ${largeArc} 0 ${end2.x} ${end2.y}`,
    'Z'
  ].join(' ');
}
```

### Color Scheme

Use HSL for rainbow distribution by angle:

```typescript
function getColor(node: DirNode, startAngle: number): string {
  const hue = (startAngle / 360) * 360;
  const saturation = 70 - (node.depth * 5); // lighter at deeper levels
  const lightness = 50 + (node.depth * 5);
  return `hsl(${hue}, ${saturation}%, ${lightness}%)`;
}
```

## File Structure

```
daisy/
├── src/
│   ├── cli.ts           # CLI entry point & arg parsing
│   ├── server.ts        # Bun HTTP server + SSE
│   ├── scanner.ts       # Directory scanning logic
│   ├── watcher.ts       # File system watcher
│   ├── types.ts         # TypeScript interfaces
│   └── utils.ts         # Helpers (formatting, debounce)
├── public/
│   ├── index.html       # Main viewer page
│   ├── sunburst.js      # SVG rendering (vanilla JS)
│   └── style.css        # Styling
├── package.json
├── tsconfig.json
├── SPEC.md
└── README.md
```

## Implementation Notes

### Bun-Specific Features

```typescript
// Native file watching
const watcher = fs.watch(path, { recursive: true }, (event, filename) => {
  // Handle change
});

// Fast file stats
const stats = await Bun.file(path).stat();

// Built-in server
Bun.serve({
  port: 3210,
  fetch(req) {
    // Handle requests
  }
});
```

### SSE Implementation

```typescript
// Server-side SSE
function createSSEStream(): Response {
  const stream = new ReadableStream({
    start(controller) {
      clients.add(controller);
    },
    cancel() {
      clients.delete(controller);
    }
  });
  
  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    }
  });
}

// Broadcast to all clients
function broadcast(event: SSEEvent) {
  const data = `data: ${JSON.stringify(event)}\n\n`;
  for (const client of clients) {
    client.enqueue(new TextEncoder().encode(data));
  }
}
```

### Performance Considerations

1. **Debounce watcher events** - Aggregate rapid changes (100-300ms window)
2. **Incremental updates** - Send deltas instead of full tree when possible
3. **Size caching** - Cache directory sizes, invalidate on change
4. **Worker threads** - Scan large directories in background
5. **Depth limiting** - Cap visualization depth for huge directories
6. **Lazy loading** - Only expand visible nodes on click

### Minimum Viable Product (MVP)

Phase 1:
- [ ] CLI argument parsing
- [ ] Directory scanning
- [ ] HTTP server with static files
- [ ] Basic SSE streaming
- [ ] Static sunburst render

Phase 2:
- [ ] File watching + live updates
- [ ] Click-to-zoom interaction
- [ ] Hover tooltips with details
- [ ] Ignore patterns

Phase 3:
- [ ] Delta updates for efficiency
- [ ] Animation transitions
- [ ] Keyboard navigation
- [ ] Export as PNG/SVG

## Dependencies

```json
{
  "name": "daisy",
  "version": "0.1.0",
  "type": "module",
  "bin": {
    "daisy": "./src/cli.ts"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.0.0"
  }
}
```

**Note:** Zero runtime dependencies. Uses only Bun built-ins.

## Browser Support

Modern browsers with:
- ES2020+ (modules, async/await)
- SVG 1.1
- EventSource API (SSE)
- CSS Grid/Flexbox

## References

- [Bun File I/O](https://bun.sh/docs/api/file-io)
- [Bun HTTP Server](https://bun.sh/docs/api/http)
- [SVG Arc Paths](https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial/Paths)
- [Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
- [Sunburst Partition Layout](https://observablehq.com/@d3/sunburst)
