# Language recipes

Contents: [Python](#python) - [Node.js](#nodejs) - [Bun](#bun) - [Go](#go) - [Rust](#rust) -
[Other runtimes](#other-runtimes)

Source pages: https://mise.jdx.dev/lang/python.html, /lang/node.html, /lang/bun.html,
/lang/go.html, /lang/rust.html, /mise-cookbook/python.html, /mise-cookbook/nodejs.html

Starter configs for these are in `assets/project/`.

## Python

mise installs precompiled python-build-standalone builds (or compiles with python-build).

```sh
mise use python@3.14 uv@latest
mise exec -- python --version
mise use python@3.13 python@3.14      # first provides `python`; each provides python3.X
mise ls-remote python                 # also pypy3.11, anaconda3, miniconda3 definitions
```

Prereleases such as `3.15.0rc3` are listed but not selected by a prefix or `latest`.

### uv project (preferred)

Expects `pyproject.toml`; `uv.lock` appears after the first `uv sync`.

```toml
[tools]
python = "3.14"
uv = "latest"
ruff = "latest"

[settings]
python.uv_venv_auto = "create|source"    # "source" if only uv should create .venv

[tasks.sync]
run = "uv sync --locked"

[tasks.test]
run = "uv run --locked pytest --cov"

[tasks.lint]
run = ["ruff check .", "ruff format --check ."]
```

- mise finds the uv project through `uv.lock`, so `python.uv_venv_auto` has no effect
  until that file exists: run `mise exec -- uv sync` once.
- To let `.python-version` (written by `uv init`) be the source of truth, drop `python`
  from `[tools]` and set `idiomatic_version_file_enable_tools = ["python"]`.
- `mise sync python --uv` makes interpreters installed by mise and by uv visible to both.
  It does not sync packages.
- New project: `mise use python@3.14 uv && mise exec -- uv init --bare && mise exec -- uv add --dev pytest pytest-cov ruff mypy`.

### requirements.txt project

```toml
[tools]
python = "3.14"
uv = "latest"

[env]
_.python.venv = { path = ".venv", create = true }

[tasks.install]
run = "uv pip install -r requirements.txt"
```

| `_.python.venv` option | Purpose |
| --- | --- |
| `path` | Environment directory, relative to the config root |
| `create` | Create it when missing |
| `python` | Version to create it with; defaults to the first configured Python |
| `python_create_args` | Arguments for `python -m venv` |
| `uv_create_args` | Arguments for `uv venv`, such as `["--seed"]` |

mise creates the venv with uv when uv is installed, otherwise with `python -m venv`
(`python.venv_stdlib = true` forces the latter). A uv-created venv has no `pip`; use
`uv pip`, or seed it with `uv_create_args = ["--seed"]`.

Both mechanisms set `VIRTUAL_ENV` and put the venv's `bin` first on `PATH` in activated
shells, under `mise exec` and in tasks. With shims alone the venv is not on `PATH`.

### Python CLIs and scripts

- Global CLIs: `mise use -g uv pipx:ansible-core` (`pipx:` and `pypi:` are the same
  backend; it uses `uv tool install` when uv is present).
- Scripts with inline dependencies (PEP 723): a file task whose shebang is
  `#!/usr/bin/env -S uv run --script`. See `assets/tasks/python-uv-task.py`.

## Node.js

```sh
mise use node@24            # node@lts, node@lts/krypton, node@latest
mise exec -- node --version
mise ls-remote node 24
```

```toml
[tools]
node = "24"
pnpm = "latest"

[env]
NODE_ENV = { default = "development" }
_.path = ["{{config_root}}/node_modules/.bin"]   # run package binaries without npx

[tasks.install]
run = "pnpm install --frozen-lockfile"
sources = ["package.json", "pnpm-lock.yaml"]
outputs = ["node_modules/.pnpm/lock.yaml"]

[tasks.dev]
depends = ["install"]
run = "pnpm run dev"
```

- mise does not read `.nvmrc`, `.node-version` or `package.json` until enabled:
  `mise settings add idiomatic_version_file_enable_tools node`. To skip `package.json`:
  `mise settings add idiomatic_version_file_disable_files node:package.json`.
- From `package.json` mise reads `devEngines.runtime` (name `node`), never `engines.node`.
- mise replaces Corepack (Node.js 25+ no longer ships it). Pin the package manager in
  `[tools]` (`npm = "11"`, `pnpm = "12"`, `yarn`), or enable
  `idiomatic_version_file_enable_tools = ["npm", "pnpm", "yarn"]` to read
  `devEngines.packageManager` / `packageManager` from `package.json`.
- Global CLIs: `mise use -g npm:prettier 'npm:@biomejs/biome'`. The npm backend installs
  with an embedded package manager, but the CLI needs `node` to run.
- Tools that belong to the project (ESLint, TypeScript, test runners) stay in
  `devDependencies` so the lockfile controls them.
- Default npm packages for every new Node install: `~/.default-npm-packages`.

## Bun

```sh
mise use bun@1
mise exec -- bun --version
```

- Upgrade with `mise upgrade bun`. `bun upgrade` replaces the binary inside mise's install
  directory without changing the recorded version.
- Version files: `.bun-version`, and `package.json` (`devEngines.runtime`,
  `devEngines.packageManager`, `packageManager`), once
  `idiomatic_version_file_enable_tools` includes `bun`.
- `bun add -g` installs under `~/.bun`; mise does not add `~/.bun/bin` to `PATH`. Use
  `mise use -g npm:<package>` for global CLIs.
- On musl systems mise picks the musl build; on x64 CPUs without AVX2, the baseline build.

## Go

```sh
mise use go@1.27
mise exec -- go version
mise use go@prefix:1.20      # series before 1.21: `go@1.20` is exactly the first 1.20 release
```

```toml
[tools]
go = "1.27"
golangci-lint = "latest"

[env]
GOTOOLCHAIN = "local"        # run the toolchain mise selected; do not download another
```

- mise sets `GOROOT` and `GOBIN` for the selected version.
- Version files (`.go-version`, `go.mod`, `go.work`) need
  `idiomatic_version_file_enable_tools` to include `go`. From `go.mod` mise reads a
  `toolchain goX.Y.Z` line, or a `go X.Y.Z` line with a patch version, as an exact
  version. A `go X.Y` line without a patch is ignored. An active `go.work` wins over the
  `go.mod` files beneath it.
- With Go's default `GOTOOLCHAIN=auto`, the `go` command can download and run a newer
  toolchain than mise selected. Compare `mise exec -- go version` with
  `mise exec -- go env GOTOOLCHAIN`.
- Go CLIs: `mise use go:golang.org/x/tools/gopls go:github.com/go-delve/delve/cmd/dlv`.
- Default packages for every new Go install: `~/.default-go-packages`.

## Rust

mise installs toolchains through rustup (installing rustup first if needed) and sets
`RUSTUP_TOOLCHAIN`.

```sh
mise use rust                 # newest stable release, such as 1.99.0
mise use rust@stable          # rustup's stable channel, updated in place by mise upgrade
mise use rust@nightly         # installed and locked as a dated nightly
mise exec -- cargo --version
```

```toml
[tools]
rust = { version = "1.99", components = ["rust-src", "llvm-tools"], targets = ["wasm32-unknown-unknown"] }
cargo-binstall = "latest"
"cargo:cargo-nextest" = "latest"
```

- `RUSTUP_TOOLCHAIN` outranks `rust-toolchain.toml`, so a global `rust` entry overrides a
  project's `rust-toolchain.toml` unless mise reads that file:
  `mise settings add idiomatic_version_file_enable_tools rust`. mise reads its `channel`,
  `profile`, `components` and `targets`.
- rustup and Cargo state stay in `~/.rustup` and `~/.cargo` (or `RUSTUP_HOME`,
  `CARGO_HOME`, or the `rust.rustup_home` / `rust.cargo_home` settings).
  `$CARGO_HOME/bin` is on `PATH` and shared by every toolchain.
- Pin a Rust CLI per project with the `cargo:` backend. With `cargo-binstall` installed,
  mise downloads a prebuilt binary when the crate publishes one, else compiles.
- Check what Cargo uses: `mise exec -- rustup show active-toolchain`.

## Other runtimes

`ruby`, `java`, `deno`, `elixir`, `erlang`, `swift`, `zig`, `dotnet` and more are core
tools: https://mise.jdx.dev/core-tools.html. Java vendors are selected by version name
(`mise ls-remote java`), and mise sets `JAVA_HOME`. Ruby may compile from source and then
needs a C toolchain and OpenSSL headers. Read the tool's `/lang/<name>.html` page before
relying on a detail.
