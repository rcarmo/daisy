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
  } = {},
): Promise<DirNode> {
  const { maxDepth = 10, ignore = [], onProgress } = options;
  const absolutePath = resolve(rootPath);
  let scannedCount = 0;

  async function scan(path: string, depth: number): Promise<DirNode> {
    const stats = await stat(path);
    const name = path.split("/").pop() ?? path;

    scannedCount++;
    if (onProgress && scannedCount % 100 === 0) {
      onProgress(scannedCount);
    }

    if (!stats.isDirectory()) {
      return {
        name,
        path,
        size: stats.size,
        isDirectory: false,
        depth,
      };
    }

    // Check cache
    const cached = sizeCache.get(path);
    if (cached && cached.mtime === stats.mtimeMs) {
      return {
        name,
        path,
        size: cached.size,
        isDirectory: true,
        depth,
        children: [], // Children not cached, would need full rescan
      };
    }

    // Scan directory contents
    const children: DirNode[] = [];
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

    return {
      name,
      path,
      size: totalSize,
      isDirectory: true,
      children,
      depth,
    };
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
