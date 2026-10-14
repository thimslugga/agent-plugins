#!/usr/bin/env node
// caveman-sessionstart.mjs -- SessionStart hook for the caveman skill.
//
// Self-contained: Node stdlib only. Resolves the default mode and prints
// the caveman ruleset for mode=caveman. Silent for off/manual.
// Fail-open: any error prints nothing and exits 0, so a broken install
// can never block a session. Never call process.exit() after writing to
// stdout: exit by falling off the end instead.
//
// Mode resolution order (mirrors upstream):
//   1. CAVEMAN_DEFAULT_MODE environment variable
//   2. repo-local .caveman/config.json or .caveman.json (walk up to fs root)
//   3. user config: $XDG_CONFIG_HOME/caveman/config.json,
//      else ~/.config/caveman/config.json
//   4. default: caveman
//
// Valid modes in this bundle: off, manual, caveman, ultracave.
// (The Classical-Chinese megacave mode was removed by request; the
// commit/review/compress modes belong to sibling skills not installed
// here.)

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const VALID_MODES = new Set(["off", "manual", "caveman", "ultracave"]);
const SILENT_MODES = new Set(["off", "manual"]);

function canonicalMode(raw) {
  if (typeof raw !== "string") return null;
  const m = raw.toLowerCase();
  return VALID_MODES.has(m) ? m : null;
}

function modeFromFile(file) {
  try {
    if (!fs.lstatSync(file).isFile()) return null;
    const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    return canonicalMode(parsed && parsed.defaultMode);
  } catch {
    return null; // absent, unreadable, malformed, or symlink: next source
  }
}

function userConfigMode() {
  let p;
  if (process.env.XDG_CONFIG_HOME) {
    p = path.join(process.env.XDG_CONFIG_HOME, "caveman", "config.json");
  } else if (process.platform === "win32") {
    p = path.join(
      process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming"),
      "caveman",
      "config.json",
    );
  } else {
    p = path.join(os.homedir(), ".config", "caveman", "config.json");
  }
  return modeFromFile(p);
}

function resolveMode() {
  const envMode = canonicalMode(process.env.CAVEMAN_DEFAULT_MODE);
  if (envMode) return envMode;
  try {
    let dir = path.resolve(process.cwd());
    for (let i = 0; i < 64; i++) {
      for (const rel of [".caveman/config.json", ".caveman.json"]) {
        const m = modeFromFile(path.join(dir, rel));
        if (m) return m;
      }
      const parent = path.dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  } catch {
    // fall through to user config
  }
  return userConfigMode() || "caveman";
}

function skillBody() {
  const skillPath = path.join(__dirname, "..", "SKILL.md");
  const text = fs.readFileSync(skillPath, "utf8");
  // Strip a leading YAML frontmatter block (--- ... --- at the very top).
  return text
    .replace(/^---[ \t]*\r?\n[\s\S]*?\r?\n---[ \t]*(?:\r?\n|$)/, "")
    .replace(/(?:\r?\n)+$/, "");
}

function main() {
  const mode = resolveMode();
  if (SILENT_MODES.has(mode)) return;
  if (mode === "ultracave") {
    process.stdout.write(
      "CAVEMAN MODE ACTIVE - mode: ultracave. " +
        "The ultracave sibling skill is not installed; falling back to the caveman ruleset.\n",
    );
  } else {
    process.stdout.write("CAVEMAN MODE ACTIVE - mode: " + mode + ".\n");
  }
  process.stdout.write("\n" + skillBody() + "\n");
}

try {
  main();
} catch {
  // Fail-open: print nothing, exit 0 by falling off the end.
}
