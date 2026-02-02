/**
 * Daisy - Type definitions
 */

/** Represents a node in the directory tree */
export interface DirNode {
  /** File or directory name */
  name: string;
  /** Absolute path */
  path: string;
  /** Size in bytes */
  size: number;
  /** Whether this is a directory */
  isDirectory: boolean;
  /** Child nodes (only for directories) */
  children?: DirNode[];
  /** Depth in the tree (0 = root) */
  depth: number;
}

/** SSE event for full tree update */
export interface FullUpdateEvent {
  type: "full";
  data: DirNode;
}

/** Delta update for incremental changes */
export interface DeltaUpdate {
  added: { path: string; node: DirNode }[];
  removed: string[];
  modified: { path: string; size: number }[];
}

/** SSE event for incremental update */
export interface DeltaUpdateEvent {
  type: "delta";
  data: DeltaUpdate;
}

/** SSE event for errors */
export interface ErrorEvent {
  type: "error";
  message: string;
}

/** SSE event for scanning progress */
export interface ScanningEvent {
  type: "scanning";
  progress: number;
}

/** Union of all SSE event types */
export type SSEEvent =
  | FullUpdateEvent
  | DeltaUpdateEvent
  | ErrorEvent
  | ScanningEvent;

/** CLI configuration options */
export interface Config {
  /** Path to watch */
  path: string;
  /** Server port */
  port: number;
  /** Maximum directory depth to scan */
  depth: number;
  /** Patterns to ignore */
  ignore: string[];
  /** Whether to open browser automatically */
  open: boolean;
  /** Whether to enable file watching */
  watch: boolean;
}

/** Server info returned by /api/info */
export interface ServerInfo {
  /** Watched path */
  path: string;
  /** Server port */
  port: number;
  /** Max depth setting */
  depth: number;
  /** Ignore patterns */
  ignore: string[];
  /** Whether watching is enabled */
  watching: boolean;
  /** Server start time */
  startedAt: string;
}

/** Sunburst rendering options */
export interface SunburstOptions {
  /** SVG width */
  width: number;
  /** SVG height */
  height: number;
  /** Inner radius (center hole) */
  innerRadius: number;
  /** Maximum depth to render */
  maxDepth: number;
  /** Color scheme */
  colorScheme: "rainbow" | "categorical" | "monochrome";
  /** Whether to show labels */
  showLabels: boolean;
  /** Minimum angle (degrees) to show label */
  minAngleForLabel: number;
}
