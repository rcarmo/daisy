/**
 * Daisy - Directory Scanner
 */

import { readdir, stat } from "node:fs/promises";
import { join, resolve } from "node:path";
import type { DirNode } from "./types.ts";
import { shouldIgnore } from "./utils.ts";

/** Size cache for directories */
const sizeCache = new Map<string, { size: number; mtime: number }>();

/**
 * Scan a directory and build a tree structure
 */
export async function scanDirectory(
  rootPath: string,
  options: {
    maxDepth?: number;
    ignore?: string[];
    onProgress?: (scanned: number) => void;
    onSnapshot?: (tree: DirNode, scanned: number) => void;
    snapshotEvery?: number;
    useCache?: boolean;
  } = {},
): Promise<DirNode> {
  const {
    maxDepth = 10,
    ignore = [],
    onProgress,
    onSnapshot,
    snapshotEvery = 250,
    useCache = true,
  } = options;
  const shouldUseCache = useCache && !onSnapshot;
  const absolutePath = resolve(rootPath);
  let scannedCount = 0;
  let rootNode: DirNode | null = null;

  function emitProgress(): void {
    if (onProgress && scannedCount % 100 === 0) {
      onProgress(scannedCount);
    }
  }

  function emitSnapshot(): void {
    if (!onSnapshot || snapshotEvery < 1) return;
    if (scannedCount % snapshotEvery === 0 && rootNode) {
      onSnapshot(rootNode, scannedCount);
    }
  }

  async function scan(path: string, depth: number): Promise<DirNode> {
    const stats = await stat(path);
    const name = path.split("/").pop() ?? path;
    const isDirectory = stats.isDirectory();

    const node: DirNode = {
      name,
      path,
      size: isDirectory ? 0 : stats.size,
      isDirectory,
      depth,
      children: isDirectory ? [] : undefined,
    };

    if (depth === 0 && !rootNode) {
      rootNode = node;
    }

    scannedCount++;
    emitProgress();
    emitSnapshot();

    if (!isDirectory) {
      return node;
    }

    // Check cache
    const cached = sizeCache.get(path);
    if (shouldUseCache && cached && cached.mtime === stats.mtimeMs) {
      node.size = cached.size;
      return node;
    }

    // Scan directory contents
    const children = node.children ?? [];
    let totalSize = 0;

    if (depth < maxDepth) {
      try {
        const entries = await readdir(path);

        for (const entry of entries) {
          if (shouldIgnore(entry, ignore)) continue;

          const childPath = join(path, entry);
          try {
            const childNode = await scan(childPath, depth + 1);
            children.push(childNode);
            totalSize += childNode.size;
            node.size = totalSize;
            emitSnapshot();
          } catch {
            // Skip inaccessible files/directories
          }
        }
      } catch {
        // Directory not readable
      }
    }

    // Sort children by size (descending)
    children.sort((a, b) => b.size - a.size);

    // Update cache
    sizeCache.set(path, { size: totalSize, mtime: stats.mtimeMs });

    node.size = totalSize;
    node.children = children;
    return node;
  }

  return scan(absolutePath, 0);
}

/**
 * Clear the size cache (call when files change)
 */
export function clearSizeCache(path?: string): void {
  if (path) {
    // Clear cache for path and all parents
    let current = path;
    while (current !== "/") {
      sizeCache.delete(current);
      current = current.split("/").slice(0, -1).join("/") || "/";
    }
  } else {
    sizeCache.clear();
  }
}

/**
 * Get total cache size (for debugging)
 */
export function getCacheSize(): number {
  return sizeCache.size;
}
