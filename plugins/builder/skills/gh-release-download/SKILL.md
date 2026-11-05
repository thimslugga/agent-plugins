---
name: gh-release-download
description: >-
  Download GitHub release assets or source archives with gh release download. 
  Use for tagged or latest releases, including downloads from a repository URL outside a Git checkout. Does not cover publishing releases or installing downloaded software.
---

# GitHub Release Download

Download the requested release into a local destination with the GitHub CLI.
Keep extraction, installation, and execution within the user's requested scope.

## Select the repository and release

Pass `--repo OWNER/REPO` explicitly when the user identifies a repository.
For a repository URL, extract `OWNER/REPO` from its path.
For example, `https://github.com/Ataraxy-Labs/sem` becomes `Ataraxy-Labs/sem`.
For another GitHub host, use `HOST/OWNER/REPO`.
No clone, `.git` directory, or temporary bare repository is necessary.

Use the exact requested tag, including its `v` prefix when present.
Omit the tag for GitHub's latest release.
You MUST not pass the literal word `latest` as a tag.
YOU MUST not substitute a newer release when a requested tag fails.

If the tag or asset name is unknown, inspect releases first. For example:

```bash
gh release list --repo Ataraxy-Labs/sem --limit 10
gh release view --repo Ataraxy-Labs/sem --json tagName,assets
gh release view v0.28.1 --repo Ataraxy-Labs/sem --json tagName,assets
```

The tag `v0.28.1` is a concrete example, not a permanent latest-version claim.
For several downloads from one latest release, resolve its tag once and reuse that tag.
This prevents a new release from changing the selection between commands.

## Choose the download type

- You MUST use `--archive zip` or `--archive tar.gz` for GitHub-generated source archives.
- You MUST use `--pattern` for uploaded assets, including binary archives.
- A source archive contains source code, not a ready-to-run sem executable.
- The source links shown on a release page do not require matching uploaded asset names.

### Tagged source archives

Download the ZIP source archive for a specific sem release:

```bash
gh release download v0.28.1 \
  --repo Ataraxy-Labs/sem \
  --archive zip \
  --dir ./downloads/sem-v0.28.1-zip
```

Download the same release as a compressed tar archive:

```bash
gh release download v0.28.1 \
  --repo Ataraxy-Labs/sem \
  --archive tar.gz \
  --dir ./downloads/sem-v0.28.1-tar
```

### Latest source archives

Download the latest sem release as ZIP:

```bash
gh release download \
  --repo Ataraxy-Labs/sem \
  --archive zip \
  --dir ./downloads/sem-latest-zip
```

Download the latest sem release as a compressed tar archive:

```bash
gh release download \
  --repo Ataraxy-Labs/sem \
  --archive tar.gz \
  --dir ./downloads/sem-latest-tar
```

### Uploaded release assets

Inspect asset names before choosing a platform-specific binary.
Match the requested operating system and architecture against those names.
Do not infer a filename from another project's naming convention.

Download all uploaded assets from a tagged release:

```bash
gh release download v0.28.1 --repo Ataraxy-Labs/sem \
  --dir ./downloads/sem-v0.28.1-assets
```

Download uploaded tar archives from the latest release:

```bash
gh release download --repo Ataraxy-Labs/sem \
  --pattern '*.tar.gz' --dir ./downloads/sem-latest-assets
```

This pattern selects every matching asset, potentially for several platforms.
For one binary, replace the pattern with an exact name from `gh release view`.
Quote patterns so the shell does not expand them against local files.
For several patterns, repeat `--pattern`.
Without a tag, supply `--pattern` or `--archive`.

## Destination and recovery

Use `--dir` for a destination directory.
For a single selected file, use `--output PATH` to choose its filename.
Use one destination method per command.

By default, an existing filename causes an error.
Use `--skip-existing` only when reusing local files satisfies the request.
That flag does not validate existing content.
Use `--clobber` only when replacement is intended.
Do not combine these two flags.

If authentication fails, examine `gh auth status` and report the missing login or token requirement.
Do not print tokens.
If a release is missing, verify the repository, exact tag, and access permissions.
If an asset pattern matches nothing, inspect asset names again.
If the user requested source code, use `--archive` instead of an asset pattern.

After a successful download, report the repository, selected tag or latest selection, and local file paths.
If validation is useful, list archive contents with `tar -tzf PATH` or `unzip -l PATH`.
Do not report success after a failed command or claim skipped files were downloaded.

## Sources

- [GitHub CLI manual](https://cli.github.com/manual/gh_release_download): command options and selection behavior.
- [GitHub CLI discussion #4306](https://github.com/cli/cli/discussions/4306): explicit repository selection outside a checkout.
- [sem releases](https://github.com/Ataraxy-Labs/sem/releases): example repository and release tags.
