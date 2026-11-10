# Tool catalog

Short names checked against the mise registry at 2026.11.6. The registry changes
weekly: confirm with `scripts/check-tools.sh <name>...` (or `mise registry <name>`)
before writing a name to a config, and find others with `mise search <text>`.

Contents: [How to read the table](#how-to-read-the-table) -
[Tables by purpose](#tables-by-purpose) - [What the backend implies](#what-the-backend-implies) -
[Not in the registry: ryl](#not-in-the-registry-ryl) - [Conflicts and overlaps](#conflicts-and-overlaps)

## How to read the table

- **Name** is what goes in `[tools]` and after `mise use`.
- **Command** is the executable to run; it often differs from the name.
- **Backend** is the first backend the registry lists; mise uses the first one the
  platform and settings allow. `mise tool <name>` shows the one in use.

Install a set at once: `mise use -g ripgrep fd jq yq fzf`. Ready-made groups are in
`assets/global/conf.d/` (apply with `scripts/apply-global-config.sh`).

## Tables by purpose

### Runtimes and package managers

| Name | Command | Backend | Notes |
| --- | --- | --- | --- |
| `python` | `python`, `pip` | `core:python` |  |
| `uv` | `uv` | `aqua:astral-sh/uv` |  |
| `node` | `node`, `npm`, `npx` | `core:node` |  |
| `pnpm` | `pnpm` | `aqua:pnpm/pnpm` |  |
| `bun` | `bun`, `bunx` | `core:bun` |  |
| `ruby` | `ruby`, `gem`, `bundle` | `core:ruby` |  |
| `go` | `go`, `gofmt` | `core:go` |  |
| `rust` | `cargo`, `rustc`, `rustup` | `core:rust` |  |
| `java` | `java`, `javac`, ... | `core:java` |  |
| `cargo-binstall` | `cargo binstall` | `aqua:cargo-bins/cargo-binstall` |  |

### Shell, search and data

| Name | Command | Backend | Notes |
| --- | --- | --- | --- |
| `neovim` | `nvim` | `vfox:jdx/vfox-neovim` | vfox plugin |
| `tmux` | `tmux` | `aqua:tmux/tmux-builds` | Linux and macOS only |
| `herdr` | `herdr` | `aqua:herdrdev/herdr` |  |
| `zmx` | `zmx` | `github:neurosnap/zmx` | Linux and macOS only |
| `fzf` | `fzf` | `aqua:junegunn/fzf` |  |
| `zoxide` | `zoxide` | `aqua:ajeetdsouza/zoxide` |  |
| `bottom` | `btm` | `aqua:ClementTsang/bottom` |  |
| `jq` | `jq` | `aqua:jqlang/jq` |  |
| `yq` | `yq` | `aqua:mikefarah/yq` |  |
| `fx` | `fx` | `aqua:antonmedv/fx` |  |
| `ripgrep` | `rg` | `aqua:BurntSushi/ripgrep` |  |
| `ag` | `ag` | `vfox:jdx/vfox-ag` | vfox plugin |
| `fd` | `fd` | `aqua:sharkdp/fd` |  |
| `ast-grep` | `sg` | `aqua:ast-grep/ast-grep` |  |
| `sd` | `sd` | `aqua:chmln/sd` |  |
| `just` | `just` | `aqua:casey/just` |  |
| `task` | `task` | `aqua:go-task/task` |  |
| `direnv` | `direnv` | `aqua:direnv/direnv` |  |
| `watchexec` | `watchexec` | `aqua:watchexec/watchexec` |  |
| `gum` | `gum` | `aqua:charmbracelet/gum` |  |
| `glow` | `glow` | `aqua:charmbracelet/glow` |  |
| `websocat` | `websocat` | `aqua:vi/websocat` |  |
| `pandoc` | `pandoc` | `github:jgm/pandoc` |  |
| `hugo` | `hugo` | `aqua:gohugoio/hugo` |  |
| `pkl` | `pkl` | `aqua:apple/pkl` |  |
| `ffmpeg` | `ffmpeg`, `ffprobe`, `ffplay` | `conda:ffmpeg` | conda package, larger install |
| `sqlite` | `sqlite3` | `conda:sqlite` | conda package, larger install |

### Git and forges

| Name | Command | Backend | Notes |
| --- | --- | --- | --- |
| `delta` | `delta` | `aqua:dandavison/delta` |  |
| `git-lfs` | `git-lfs` | `aqua:git-lfs/git-lfs` |  |
| `gh` | `gh` | `aqua:cli/cli` | alias of `github-cli` |
| `glab` | `glab` | `gitlab:gitlab-org/cli` |  |
| `act` | `act` | `aqua:nektos/act` |  |
| `git-cliff` | `git-cliff` | `aqua:orhun/git-cliff` |  |
| `lazygit` | `lazygit` | `aqua:jesseduffield/lazygit` |  |
| `jj` | `jj` | `aqua:jj-vcs/jj` |  |
| `prek` | `prek` | `aqua:j178/prek` |  |

### Secrets and supply chain

| Name | Command | Backend | Notes |
| --- | --- | --- | --- |
| `gitleaks` | `gitleaks` | `aqua:gitleaks/gitleaks` |  |
| `betterleaks` | `betterleaks` | `aqua:betterleaks/betterleaks` |  |
| `trufflehog` | `trufflehog` | `aqua:trufflesecurity/trufflehog` |  |
| `sops` | `sops` | `aqua:getsops/sops` |  |
| `age` | `age`, `age-keygen` | `aqua:FiloSottile/age` |  |
| `cosign` | `cosign` | `aqua:sigstore/cosign` |  |
| `trivy` | `trivy` | `aqua:aquasecurity/trivy` |  |
| `osv-scanner` | `osv-scanner` | `aqua:google/osv-scanner` |  |
| `semgrep` | `semgrep` | `pipx:semgrep` | needs `uv` (and `python`) |

### AWS

| Name | Command | Backend | Notes |
| --- | --- | --- | --- |
| `awscli` | `aws` | `aqua:aws/aws-cli` | alias of `aws-cli`; Linux and macOS only |
| `aws-sam-cli` | `sam` | `aqua:aws/aws-sam-cli` | alias of `aws-sam` |
| `aws-cdk` | `cdk` | `npm:aws-cdk` | needs `node` |
| `aws-amplify` | `amplify` | `github:aws-amplify/amplify-cli` |  |
| `amazon-ecr-credential-helper` | `docker-credential-ecr-login` | `aqua:awslabs/amazon-ecr-credential-helper` |  |
| `aws-vault` | `aws-vault` | `aqua:ByteNess/aws-vault` |  |

### Infrastructure as code, Kubernetes, containers

| Name | Command | Backend | Notes |
| --- | --- | --- | --- |
| `opentofu` | `tofu` | `aqua:opentofu/opentofu` |  |
| `terraform` | `terraform` | `aqua:hashicorp/terraform` |  |
| `terragrunt` | `terragrunt` | `aqua:gruntwork-io/terragrunt` |  |
| `tflint` | `tflint` | `aqua:terraform-linters/tflint` |  |
| `packer` | `packer` | `aqua:hashicorp/packer` |  |
| `vault` | `vault` | `aqua:hashicorp/vault` |  |
| `kubectl` | `kubectl` | `aqua:kubernetes/kubernetes/kubectl` |  |
| `helm` | `helm` | `aqua:helm/helm` |  |
| `oc` | `oc` | `http:oc` |  |
| `ansible` | `ansible`, `ansible-playbook`, ... | `pipx:ansible` | needs `uv` (and `python`) |
| `ansible-core` | `ansible`, `ansible-playbook`, ... | `pipx:ansible-core` | needs `uv` (and `python`) |
| `devcontainer-cli` | `devcontainer` | `npm:@devcontainers/cli` | needs `node` |
| `dive` | `dive` | `aqua:wagoodman/dive` |  |
| `hadolint` | `hadolint` | `aqua:hadolint/hadolint` |  |

### Agent tooling

| Name | Command | Backend | Notes |
| --- | --- | --- | --- |
| `rtk` | `rtk` | `aqua:rtk-ai/rtk` |  |
| `agent-browser` | `agent-browser` | `aqua:vercel-labs/agent-browser` |  |
| `playwright` | `playwright` | `npm:playwright` | needs `node` |

### Lint, format and language servers

| Name | Command | Backend | Notes |
| --- | --- | --- | --- |
| `shellcheck` | `shellcheck` | `aqua:koalaman/shellcheck` |  |
| `shfmt` | `shfmt` | `aqua:mvdan/sh` |  |
| `ruff` | `ruff` | `aqua:astral-sh/ruff` |  |
| `ty` | `ty` | `aqua:astral-sh/ty` |  |
| `golangci-lint` | `golangci-lint` | `aqua:golangci/golangci-lint` |  |
| `gofumpt` | `gofumpt` | `aqua:mvdan/gofumpt` |  |
| `rust-analyzer` | `rust-analyzer` | `aqua:rust-lang/rust-analyzer` |  |
| `stylua` | `stylua` | `aqua:JohnnyMorganz/StyLua` |  |
| `oxlint` | `oxlint` | `aqua:oxc-project/oxc/oxlint` |  |
| `oxfmt` | `oxfmt` | `npm:oxfmt` | needs `node` |
| `prettier` | `prettier` | `npm:prettier` | needs `node` |
| `yamllint` | `yamllint` | `pipx:yamllint` | needs `uv` (and `python`) |
| `yamlfmt` | `yamlfmt` | `aqua:google/yamlfmt` |  |
| `cfn-lint` | `cfn-lint` | `pipx:cfn-lint` | needs `uv` (and `python`) |
| `tombi` | `tombi` | `aqua:tombi-toml/tombi` |  |
| `taplo` | `taplo` | `aqua:tamasfe/taplo` |  |
| `actionlint` | `actionlint` | `aqua:rhysd/actionlint` |  |
| `rumdl` | `rumdl` | `aqua:rvben/rumdl` |  |
| `lychee` | `lychee` | `aqua:lycheeverse/lychee` |  |
| `vale` | `vale` | `aqua:vale-cli/vale` |  |
| `typos` | `typos` | `aqua:crate-ci/typos` |  |
| `editorconfig-checker` | `editorconfig-checker` | `github:editorconfig-checker/editorconfig-checker` |  |
## What the backend implies

| Backend | Consequence |
| --- | --- |
| `core:` | Built into mise. No other tool needed. `ruby` may compile from source and then needs a C toolchain. |
| `aqua:`, `github:`, `gitlab:`, `http:` | Prebuilt release binaries with checksum (and often attestation) checks. Heavy use can hit GitHub rate limits: set `GITHUB_TOKEN` or `MISE_GITHUB_TOKEN`. |
| `pipx:` (same as `pypi:`) | Installed with `uv tool install` when uv is present, otherwise pipx. Put `uv` and `python` in the same config; mise installs them first. |
| `npm:` | Installed by mise's embedded package manager, but the CLI needs `node` in `[tools]` to run. |
| `cargo:` | Compiles unless `cargo-binstall` is installed and the crate ships binaries. Needs `rust`. |
| `conda:` | Self-contained with its shared libraries; large. |
| `vfox:` | A Lua plugin does the install. `ag` also needs libpcre on the host. |

Platform limits in the registry: `tmux`, `zmx` and `awscli` (`aws-cli`) are Linux and
macOS only. In a config shared with Windows, write
`awscli = { version = "latest", os = ["linux", "macos"] }` and install the AWS CLI on
Windows with its MSI or winget.

## Not in the registry: ryl

`ryl` (https://github.com/owenlamont/ryl) is a YAML linter and formatter written in
Rust with yamllint-compatible rules. It has no registry short name, so name a backend:

```sh
mise use -g uv pipx:ryl          # PyPI package; no Rust toolchain needed
# alternatives: 'npm:@owenlamont/ryl' (needs node), cargo:ryl (compiles), conda:ryl
mise exec -- ryl check --enable ALL .          # one-off run with every rule
mise exec -- ryl check --fix . && mise exec -- ryl format .
mise exec -- ryl format --check .              # CI
```

- ryl enables no rules by default: add a `.ryl.toml` at the project root or pass
  `--enable <RULES>` / `--disable <RULES>`.
- `ryl check` is the lint subcommand; bare `ryl <paths>` is deprecated.
- Legacy `.yamllint`, `.yamllint.yml` and `.yamllint.yaml` files still load but warn.
  Convert them with `ryl --migrate-configs --migrate-write`.
- `ryl server` is an LSP server over stdio.
- Hook repo for prek and pre-commit: https://github.com/owenlamont/ryl-pre-commit
  (ids `ryl-check`, `ryl-format`, `ryl-check-markdown`, `ryl-format-markdown`; see
  `assets/ci/pre-commit-config.yaml`). Docs: https://ryl-docs.pages.dev/

## Conflicts and overlaps

- `ansible` and `ansible-core` both provide `ansible`, `ansible-playbook` and the
  rest. Install one: `ansible-core` for the engine only, `ansible` for the community
  package (it exposes the ansible-core commands).
- `yamllint`, `yamlfmt` and `ryl` overlap. One linter and one formatter per project.
- `tombi` and `taplo` are both TOML formatters and linters; pick one. `mise fmt`
  formats mise's own config files.
- `gitleaks`, `betterleaks` and `trufflehog` are all secret scanners; running more
  than one in a hook slows every commit.
- `terraform` and `opentofu` install different commands (`terraform`, `tofu`), so
  both can be present.
- `rust-analyzer` is also a rustup component:
  `rust = { version = "stable", components = ["rust-analyzer"] }` keeps it matched to
  the toolchain.
- `ripgrep` and `ag` do the same job; `ag` is the slower install.
- `prettier`, `oxfmt` and `oxlint` are usually better as project `devDependencies`
  so the lockfile controls their versions; the mise entries suit ad-hoc global use.
