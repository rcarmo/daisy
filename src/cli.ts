#!/usr/bin/env bun
/**
 * Daisy - CLI Entry Point
 *
 * Live disk usage sunburst visualizer using SSE
 */

import { resolve } from "node:path";
import { parseArgs } from "node:util";
import { startServer } from "./server.ts";
import type { Config } from "./types.ts";
import { DEFAULT_IGNORE } from "./utils.ts";

const VERSION = "0.1.0";

const HELP = `
🌼 Daisy - Live Disk Usage Sunburst Visualizer

Usage: daisy [options] <path>

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
`;

function printHelp(): void {
  console.log(HELP);
  process.exit(0);
}

function printVersion(): void {
  console.log(`daisy v${VERSION}`);
  process.exit(0);
}

function parseCliArgs(): Config {
  const { values, positionals } = parseArgs({
    args: Bun.argv.slice(2),
    options: {
      port: { type: "string", short: "p", default: "3210" },
      depth: { type: "string", short: "d", default: "10" },
      ignore: { type: "string", short: "i", multiple: true },
      open: { type: "boolean", short: "o", default: false },
      watch: { type: "boolean", short: "w", default: true },
      "no-watch": { type: "boolean", default: false },
      help: { type: "boolean", short: "h", default: false },
      version: { type: "boolean", short: "v", default: false },
    },
    allowPositionals: true,
  });

  if (values.help) printHelp();
  if (values.version) printVersion();

  const path = positionals[0] ?? ".";
  const port = Number.parseInt(values.port ?? "3210", 10);
  const depth = Number.parseInt(values.depth ?? "10", 10);

  if (Number.isNaN(port) || port < 1 || port > 65535) {
    console.error("Error: Invalid port number");
    process.exit(1);
  }

  if (Number.isNaN(depth) || depth < 1) {
    console.error("Error: Invalid depth");
    process.exit(1);
  }

  return {
    path: resolve(path),
    port,
    depth,
    ignore: [...DEFAULT_IGNORE, ...(values.ignore ?? [])],
    open: values.open ?? false,
    watch: values["no-watch"] ? false : (values.watch ?? true),
  };
}

async function openBrowser(url: string): Promise<void> {
  const { platform } = process;
  const commands: Record<string, string[]> = {
    darwin: ["open", url],
    linux: ["xdg-open", url],
    win32: ["cmd", "/c", "start", url],
  };

  const cmd = commands[platform];
  if (cmd) {
    const [command, ...args] = cmd;
    Bun.spawn([command, ...args], { stdio: ["ignore", "ignore", "ignore"] });
  }
}

// Main
const config = parseCliArgs();

console.log(`
🌼 Daisy v${VERSION}
   Path:  ${config.path}
   Port:  ${config.port}
   Depth: ${config.depth}
   Watch: ${config.watch ? "enabled" : "disabled"}
`);

startServer(config);

if (config.open) {
  openBrowser(`http://localhost:${config.port}`);
}

// Handle shutdown
process.on("SIGINT", () => {
  console.log("\n👋 Shutting down...");
  process.exit(0);
});
