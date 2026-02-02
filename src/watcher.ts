/**
 * Daisy - File System Watcher
 */

import { type FSWatcher, watch } from "node:fs";
import { resolve } from "node:path";
import { clearSizeCache } from "./scanner.ts";
import { debounce } from "./utils.ts";

export type WatchCallback = (event: string, filename: string | null) => void;

let watcher: FSWatcher | null = null;

/**
 * Start watching a directory for changes
 */
export function startWatching(
  path: string,
  callback: WatchCallback,
  debounceMs = 300,
): void {
  const absolutePath = resolve(path);

  // Stop any existing watcher
  stopWatching();

  // Create debounced callback
  const debouncedCallback = debounce(
    (event: string, filename: string | null) => {
      // Clear cache for changed path
      if (filename) {
        clearSizeCache(`${absolutePath}/${filename}`);
      } else {
        clearSizeCache();
      }
      callback(event, filename);
    },
    debounceMs,
  );

  try {
    watcher = watch(
      absolutePath,
      { recursive: true },
      (event: string, filename: string | null) => {
        debouncedCallback(event, filename);
      },
    );

    watcher.on("error", (error: Error) => {
      console.error("Watcher error:", error.message);
    });

    console.log(`👀 Watching ${absolutePath} for changes...`);
  } catch (error) {
    console.error("Failed to start watcher:", error);
  }
}

/**
 * Stop watching
 */
export function stopWatching(): void {
  if (watcher) {
    watcher.close();
    watcher = null;
    console.log("Stopped watching");
  }
}

/**
 * Check if watcher is active
 */
export function isWatching(): boolean {
  return watcher !== null;
}
