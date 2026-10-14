# playwright-skill

General-purpose Playwright browser automation for coding agents. Writes and
executes focused Playwright scripts for testing websites, automating browser
interactions, validating web functionality, and browser-based testing. Covers
screenshots, responsive checks, UX validation, login flows, link checks, network
interception, API mocking, auth state, video, visual checks, device emulation,
and CI patterns.

Upstream: https://github.com/lackeyjb/playwright-skill (MIT, v5.0.0).

## Layout

- `SKILL.md` — the skill: path resolution, workflow, setup, patterns, common
  tasks, helpers, configuration.
- `references/api-reference.md` — full API reference (upstream API_REFERENCE.md).
- `scripts/run.js` — script executor. Runs a script file or an inline `-e`
  snippet with Playwright pre-required, sets `NODE_PATH` and `PW_SKILL_DIR`,
  exits when the snippet settles, and optionally preserves scripts via
  `PW_SCRIPT_DIR`.
- `scripts/lib/helpers.js` — helpers: `detectDevServers`, `launchBrowser`,
  `createContext`, `handleCookieBanner`, `takeScreenshot`,
  `getExtraHeadersFromEnv`.
- `package.json` / `package-lock.json` — `npm run setup` installs Playwright
  and Chromium; `npm run install-all-browsers` adds Firefox and WebKit.
- `agents/` — harness adaptation notes (`openai.yaml`, `harness-notes.md`).
- `LICENSE`, `ATTRIBUTION.md` — upstream license and credit.

Local layout note: upstream ships `run.js` and `lib/` at the skill root; they
were moved to `scripts/` per local convention. `scripts/run.js` resolves the
skill root as its parent, so `npm install` / `npm run setup` still run in the
skill root and `SKILL_DIR` still means the directory containing `SKILL.md`.
`SKILL.md` path references were updated to match; nothing else changed.

## Usage

Drop this directory into any agent's skills folder (for example
`~/workspace/skills/playwright-skill/`). Requires Node.js 20+ and network
access on first setup:

```bash
cd ~/workspace/skills/playwright-skill && npm run setup
```

Then point the agent at it. The agent sets `SKILL_DIR` to the skill directory
and follows `SKILL.md`: detect dev servers, write a script to the temp dir,
run `node "$SKILL_DIR/scripts/run.js" <script.js>`, and report with artifacts.

Headless is not the default; the skill prefers a visible browser unless
`headless: true` is requested or there is no display. In headless sandboxes
set `PW_HEADLESS=true`.

## Testing

- `node --check scripts/run.js scripts/lib/helpers.js` — syntax clean.
- `SKILL.md` frontmatter parses (name, description, license MIT,
  compatibility note, version 5.0.0).
- The `references/api-reference.md` link from `SKILL.md` resolves.
- Upstream's own test suite (`tests/` in the repo) was not run here: it needs
  a real Chromium install, which this sandbox cannot provide reliably.
