/**
 * Daisy - HTTP Server with SSE
 */

import { join, resolve } from "node:path";
import { getIndexHtml } from "./assets.ts";
import { scanDirectory } from "./scanner.ts";
import type { Config, DirNode, SSEEvent, ServerInfo } from "./types.ts";
import { formatBytes, getMimeType } from "./utils.ts";
import { isWatching, startWatching, stopWatching } from "./watcher.ts";

/** Connected SSE clients */
const clients = new Set<ReadableStreamDefaultController<Uint8Array>>();

/** Current directory tree */
let currentTree: DirNode | null = null;

/** Scan generation to prevent out-of-order updates */
let scanGeneration = 0;

/** Server start time */
let startedAt: Date;

/** Text encoder for SSE */
const encoder = new TextEncoder();

/**
 * Broadcast an event to all connected clients
 */
function broadcast(event: SSEEvent): void {
  const data = `data: ${JSON.stringify(event)}\n\n`;
  const encoded = encoder.encode(data);

  for (const controller of clients) {
    try {
      controller.enqueue(encoded);
    } catch {
      clients.delete(controller);
    }
  }
}

/**
 * Perform a full scan and broadcast results
 */
async function performScan(config: Config): Promise<void> {
  broadcast({ type: "scanning", progress: 0 });

  scanGeneration += 1;
  const currentGeneration = scanGeneration;

  let lastProgressAt = 0;
  let lastSnapshotAt = 0;
  const minIntervalMs = 200;

  try {
    currentTree = await scanDirectory(config.path, {
      maxDepth: config.depth,
      ignore: config.ignore,
      snapshotEvery: config.progressEvery,
      useCache: !config.watch,
      onProgress: (count) => {
        if (currentGeneration !== scanGeneration) return;
        const now = Date.now();
        if (now - lastProgressAt >= minIntervalMs) {
          lastProgressAt = now;
          broadcast({ type: "scanning", progress: count });
        }
      },
      onSnapshot: (tree) => {
        if (currentGeneration !== scanGeneration) return;
        const now = Date.now();
        if (now - lastSnapshotAt >= minIntervalMs) {
          lastSnapshotAt = now;
          broadcast({ type: "snapshot", data: tree });
        }
      },
    });

    if (currentGeneration !== scanGeneration) return;

    broadcast({ type: "full", data: currentTree });
    console.log(`📊 Scanned ${config.path}: ${formatBytes(currentTree.size)}`);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    broadcast({ type: "error", message });
    console.error("Scan error:", message);
  }
}

/**
 * Create SSE response stream
 */
function createSSEStream(): Response {
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      clients.add(controller);

      // Send current tree immediately if available
      if (currentTree) {
        const data = `data: ${JSON.stringify({ type: "full", data: currentTree })}\n\n`;
        controller.enqueue(encoder.encode(data));
      }
    },
    cancel() {
      // Client will be removed when enqueue fails
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

/**
 * Serve static files - uses embedded assets for compiled binary
 */
function serveStatic(path: string): Response {
  // For the index page, serve from embedded assets
  if (path === "/" || path === "/index.html") {
    return new Response(getIndexHtml(), {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  }

  // For other static files, try embedded assets first, then filesystem
  // In compiled binary mode, we only have embedded assets
  return new Response("Not Found", { status: 404 });
}

/**
 * Start the HTTP server
 */
export function startServer(config: Config): void {
  startedAt = new Date();

  const server = Bun.serve({
    port: config.port,
    fetch: async (req: Request) => {
      const url = new URL(req.url);
      const path = url.pathname;

      // API routes
      if (path === "/api/events") {
        return createSSEStream();
      }

      if (path === "/api/tree") {
        if (!currentTree) {
          return new Response(JSON.stringify({ error: "No data yet" }), {
            status: 503,
            headers: { "Content-Type": "application/json" },
          });
        }
        return new Response(JSON.stringify(currentTree), {
          headers: { "Content-Type": "application/json" },
        });
      }

      if (path === "/api/info") {
        const info: ServerInfo = {
          path: resolve(config.path),
          port: config.port,
          depth: config.depth,
          ignore: config.ignore,
          watching: isWatching(),
          startedAt: startedAt.toISOString(),
        };
        return new Response(JSON.stringify(info), {
          headers: { "Content-Type": "application/json" },
        });
      }

      if (path === "/api/reveal") {
        const targetPath = url.searchParams.get("path");
        if (!targetPath) {
          return new Response(JSON.stringify({ error: "Missing path" }), {
            status: 400,
            headers: { "Content-Type": "application/json" },
          });
        }

        const absolutePath = resolve(targetPath);
        const platform = process.platform;
        if (platform === "darwin") {
          Bun.spawn(["open", "-R", absolutePath], { stdio: ["ignore", "ignore", "ignore"] });
        } else if (platform === "win32") {
          Bun.spawn(["cmd", "/c", "start", "", absolutePath], { stdio: ["ignore", "ignore", "ignore"] });
        } else {
          Bun.spawn(["xdg-open", absolutePath], { stdio: ["ignore", "ignore", "ignore"] });
        }

        return new Response(JSON.stringify({ status: "ok" }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      if (path === "/api/rescan") {
        performScan(config);
        return new Response(JSON.stringify({ status: "scanning" }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      // Static files
      return serveStatic(path);
    },
  });

  console.log(`🌼 Daisy running at http://localhost:${server.port}`);

  // Initial scan
  performScan(config);

  // Start watching if enabled
  if (config.watch) {
    startWatching(config.path, () => {
      console.log("📁 Change detected, rescanning...");
      performScan(config);
    });
  }
}

/**
 * Stop the server
 */
export function stopServer(): void {
  stopWatching();
  // Close all client connections
  for (const controller of clients) {
    try {
      controller.close();
    } catch {
      // Ignore
    }
  }
  clients.clear();
}
