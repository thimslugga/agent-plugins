# Lockfile, CI and Docker

Contents: [Lockfile](#lockfile) - [GitHub Actions](#github-actions) - [GitLab CI](#gitlab-ci) -
[Bootstrap wrapper](#bootstrap-wrapper) - [Docker](#docker) - [Dev containers](#dev-containers)

Source pages: https://mise.jdx.dev/dev-tools/mise-lock.html, /continuous-integration.html,
/mise-cookbook/docker.html. Templates: `assets/ci/`.

## Lockfile

`mise.lock` records the exact versions the requests in `mise.toml` resolved to, with
download URLs and checksums where the backend provides them.

```sh
mise lock                                                # write mise.lock; installs nothing
mise lock --platform linux-x64,linux-arm64,macos-arm64   # one entry per platform in use
mise install --locked                                    # fail on anything not locked
mise lock --bump node && mise install --locked           # move one tool forward
mise lock --global                                       # lock the global config's tools
```

- Commit `mise.toml`, `mise.lock`, and `.mise/locks/` if mise created it (dependency
  graphs for npm and PyPI tools).
- `lockfile = true` under `[settings]` makes mise create and update lockfiles on install
  and upgrade. Unset: existing lockfiles are kept up to date but none is created.
- `[tool_config] locked = true` (or `--locked`) requires every tool of that config root
  to resolve from its lockfile.
- Each config file has its own lockfile: `mise.toml` -> `mise.lock`,
  `mise.test.toml` -> `mise.test.lock`, `mise.local.toml` -> `mise.local.lock` (do not
  commit).
- Tools listed only in `.tool-versions` are not locked; move them to `mise.toml`.
- `mise.lock` covers tools, not application dependencies: keep `uv.lock`,
  `package-lock.json`, `Cargo.lock` as well.
- A locked install still needs the network for downloads that are not cached.
- `mise upgrade` updates the lockfile; `mise upgrade --bump` also rewrites the request.

## GitHub Actions

`jdx/mise-action` installs mise and the repository's tools, caches them, adds shims to
`PATH`, and exports the project's environment to later steps. With a `mise.lock` it runs
`mise install --locked`.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: jdx/mise-action@v5
        # with:
        #   version: 2026.10.4        # pin mise itself
        #   working_directory: app    # select a subproject
      - run: mise run test
```

- CI needs no shell activation: use `mise run <task>` or `mise exec -- <cmd>`.
- A restored tool cache is trusted as is. To cache downloads instead, which mise checks
  against the lockfile, cache `~/.cache/mise/downloads-cas` keyed on
  `hashFiles('mise.lock')` and set `cache: false` on the action.
- The action passes the workflow token to mise during install but does not export it. If
  later steps install tools or hit rate limits, set `GITHUB_TOKEN` for them.
- Scaffold a workflow: `mise generate github-action --write --task=ci` (review triggers
  and action versions before committing).

## GitLab CI

With the official image:

```yaml
build-job:
  stage: build
  image: ghcr.io/jdx/mise:2026.10.4-debian
  variables:
    MISE_DATA_DIR: $CI_PROJECT_DIR/.mise
    MISE_CACHE_DIR: $CI_PROJECT_DIR/.mise/cache
  cache:
    key:
      prefix: mise-debian13-amd64
      files: [mise.toml, mise.lock]
    paths:
      - .mise/installs/
      - .mise/cache/
  script:
    - mise install --locked
    - mise run build
```

Without a lockfile, drop `mise.lock` from the cache key and `--locked` from the install.

## Bootstrap wrapper

For contributors and runners without mise, commit a wrapper that downloads a pinned mise
on first use:

```sh
mise generate install-script --localize --write bin/mise    # add --windows for bin/mise.cmd
mise generate task-stubs --mise-bin ./bin/mise              # bin/<task> for every project task
./bin/mise install
```

Commit `bin/` and add `.mise/` to `.gitignore`; the localized wrapper keeps mise, its
tools and its cache there. Regenerate the wrapper to move to a newer mise.

## Docker

Official images, published for every stable release since 2026.9.11 to `ghcr.io/jdx/mise`
and Docker Hub `jdxcode/mise`, for `linux/amd64` and `linux/arm64`:

| Image | Example tags | Use it for |
| --- | --- | --- |
| Scratch | `2026.10.4`, `2026.10`, `latest` | Copying the static musl binary into your own image |
| Debian slim | `2026.10.4-debian`, `2026.10-debian`, `debian` | CI jobs and development containers |

Both set `MISE_DATA_DIR=/mise`, `MISE_CONFIG_DIR=/mise`, `MISE_CACHE_DIR=/mise/cache` and
add `/mise/shims` to `PATH`. The Debian image (trixie) includes `ca-certificates`, `curl`,
`git` and `libatomic1`, and has no `ENTRYPOINT`. Neither preinstalls tools. Month and
floating tags move; pin a full version or a digest
(`docker buildx imagetools inspect ghcr.io/jdx/mise:2026.10.4`).

Build on the Debian image (`assets/ci/Dockerfile`):

```Dockerfile
FROM ghcr.io/jdx/mise:2026.10.4-debian
WORKDIR /app
COPY mise.toml mise.lock ./
RUN mise trust && mise install --locked
COPY . .
CMD ["mise", "exec", "--", "node", "server.js"]
```

Copy the static binary into your own base. It runs on glibc and musl systems, so the same
`COPY --from` line works on Alpine, Fedora and Amazon Linux bases; only the package
manager line changes:

```Dockerfile
FROM debian:13-slim
COPY --from=ghcr.io/jdx/mise:2026.10.4 /usr/local/bin/mise /usr/local/bin/mise
RUN apt-get update \
    && apt-get -y --no-install-recommends install ca-certificates git \
    && rm -rf /var/lib/apt/lists/*
ENV MISE_DATA_DIR="/mise"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
ENV PATH="/mise/shims:$PATH"
WORKDIR /app
COPY mise.toml ./
RUN mise trust && mise install
COPY . .
```

Rules that keep builds correct:

- Copy `mise.toml` (and `mise.lock`, `.mise/locks/`) before the sources and run
  `mise install` in its own layer, so tools rebuild only when the config changes.
- `COPY --from` copies only the binary: set the `MISE_*` directories and `PATH` yourself
  and install CA certificates and any OS packages the tools need.
- Build shells are not activated. Use `mise exec -- <cmd>` or `mise run <task>` in `RUN`
  and `CMD`. Shims on `PATH` cover plain command names.
- `mise trust` is needed when the config has `[env]`, hooks, templates or tool options.
- Lock the image's platforms: `mise lock --platform linux-x64,linux-arm64`.
- Exclude credentials and personal overrides with `.dockerignore`
  (`assets/ci/dockerignore`): `.env`, `.env.*`, `**/*.local.toml`.
- A running container never updates mise. Rebuild, or run `mise self-update`.
- For private GitHub release assets or rate limits, pass a token as a build secret
  (`--mount=type=secret`), not as an `ARG` or `ENV`.

Other ways to get mise into an image: packslip pinned by digest, distribution packages
(apt via `extrepo`, dnf COPR, `apk add mise`), a minisign-verified release download, the
committed `bin/mise` wrapper, or the `mise.run` script with `MISE_VERSION` set.

## Dev containers

```sh
mise generate devcontainer --write                    # .devcontainer/devcontainer.json
mise generate devcontainer --write --mount-mise-data  # keep installed tools across rebuilds
```

The file adds the mise dev container feature and the mise-vscode extension, and sets
`postCreateCommand` to `mise install`.
