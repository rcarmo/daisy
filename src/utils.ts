/**
 * Daisy - Utility functions
 */

/**
 * Format bytes to human-readable string
 */
export function formatBytes(bytes: number): string {
  if (bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB", "TB", "PB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${(bytes / k ** i).toFixed(1)} ${sizes[i]}`;
}

/**
 * Create a debounced version of a function
 */
export function debounce<T extends (...args: never[]) => void>(
  fn: T,
  delay: number,
): (...args: Parameters<T>) => void {
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  return (...args: Parameters<T>) => {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }
    timeoutId = setTimeout(() => {
      fn(...args);
      timeoutId = null;
    }, delay);
  };
}

/**
 * Check if a path matches any of the ignore patterns
 */
export function shouldIgnore(path: string, patterns: string[]): boolean {
  const name = path.split("/").pop() ?? "";

  for (const pattern of patterns) {
    // Simple glob matching
    if (pattern.startsWith("*")) {
      const suffix = pattern.slice(1);
      if (name.endsWith(suffix)) return true;
    } else if (pattern.endsWith("*")) {
      const prefix = pattern.slice(0, -1);
      if (name.startsWith(prefix)) return true;
    } else if (name === pattern) {
      return true;
    }
  }

  return false;
}

/**
 * Default ignore patterns
 */
export const DEFAULT_IGNORE = [
  "node_modules",
  ".git",
  ".DS_Store",
  "*.swp",
  "*.swo",
  ".Trash",
  "__pycache__",
  ".pytest_cache",
  ".mypy_cache",
  "coverage",
  "dist",
  ".next",
  ".turbo",
];

/**
 * Get MIME type for a file extension
 */
export function getMimeType(path: string): string {
  const ext = path.split(".").pop()?.toLowerCase() ?? "";
  const mimeTypes: Record<string, string> = {
    html: "text/html",
    css: "text/css",
    js: "application/javascript",
    json: "application/json",
    png: "image/png",
    svg: "image/svg+xml",
    ico: "image/x-icon",
  };
  return mimeTypes[ext] ?? "application/octet-stream";
}
