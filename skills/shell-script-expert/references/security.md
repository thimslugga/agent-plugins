# Command injection and shell security

Command injection happens when untrusted data reaches a shell that parses it.
The shell then treats the data as syntax rather than as a value. Anything that
takes input from a web form, an HTTP header, a cookie, a filename, a webhook,
an environment variable, or a CI variable is untrusted.

## The structural fix

Pass arguments as arguments. Never assemble a command as a string and hand the
string to a shell to re-parse:

```bash
# Vulnerable: the value is parsed as shell syntax.
# filename='report.txt; rm -rf /' runs both commands.
eval "cat ${filename}"
sh -c "cat ${filename}"
ssh host "cat ${filename}"

# Safe: the value stays one argument, whatever characters it contains.
cat -- "${filename}"
```

The metacharacters that turn a value into syntax are `; & && || | > < $( )` and newline. Rather than trying to ban them, validate against a positive
rule, because the legal set is always easier to define than the illegal set.

## Validate with an allowlist

```bash
#######################################
# Reject an identifier that is not a plain safe name.
# Arguments:
#   Candidate string.
# Returns:
#   0 when the value is acceptable, 1 otherwise.
#######################################
validate_name() {
  local value="$1"
  if [[ ! "${value}" =~ ^[A-Za-z0-9_-]+$ ]]; then
    return 1
  fi
  return 0
}

if ! validate_name "${service}"; then
  die "invalid service name: ${service}"
fi
```

For a fixed set of choices, a `case` is stronger than a regex because nothing
outside the list can pass:

```bash
case "${action}" in
  start | stop | restart) systemctl "${action}" myapp ;;
  *) die "unsupported action: ${action}" ;;
esac
```

Path arguments need their own check. Reject `..` and anything that leaves the
expected directory, then compare the resolved path. Require a canonicalizer
that exists on the target fleet rather than assuming GNU `readlink -f` is
available:

```bash
require_cmds realpath
if [[ "${candidate}" != /* ]]; then
  candidate="./${candidate}"
fi
local resolved
resolved="$(realpath "${candidate}")"
if [[ "${resolved}" != "${ALLOWED_ROOT}"/* ]]; then
  die "path escapes ${ALLOWED_ROOT}: ${candidate}"
fi
```

`realpath` option support varies on older systems. If the target lacks a safe
canonicalizer, handle the path in Python instead of approximating symlink
resolution with `cd` and `pwd`.

## The environment is part of the attack surface

OWASP's examples show two environment attacks that apply directly to shell:

1. **A tampered `PATH`.** A script that calls `make` or `curl` by bare name
   runs whatever appears first on `PATH`. In any script that runs with
   elevated privileges or from a service manager, set `PATH` explicitly at the
   top and mark it readonly, or call the binaries by absolute path.
2. **A tampered configuration variable.** A script that builds a command from
   `${APP_HOME}` or similar lets whoever controls that variable choose the
   binary. Validate the value before using it, exactly as with any other
   input.

```bash
readonly PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
```

Also unset or ignore `IFS`, `CDPATH`, `BASH_ENV`, and `LD_PRELOAD` when the
caller is not trusted.

## Privilege

- SUID and SGID on shell scripts are forbidden. The guide is unambiguous: too
  many holes to close. Use `sudo` with a narrowly scoped sudoers rule instead.
- Drop privileges as early as possible, and require the caller to hold them
  rather than calling `sudo` from inside the script.
- A privileged script should read its input from arguments and files it
  controls, never from the environment of an unprivileged caller.

## Secrets

- Never pass a secret as a command-line argument. Every user on the host can
  read it from `ps`. Use an environment variable, a file with `0600`
  permissions, or standard input.
- `set -x` prints secrets. Disable tracing around the sensitive lines:

```bash
set +x
printf '%s' "${token}" | some_tool --token-stdin
set -x
```

- Redact before logging. A log line that echoes the full command is a leak.

## Files

- Create temporary files with `mktemp`. A predictable name in a shared
  directory allows another user to pre-create it as a symlink pointing
  somewhere valuable.
- Set `umask 077` before writing anything that should not be world readable.
- Prefer atomic replacement over in-place editing: write to a temp file in the
  same filesystem, then `mv` it into position.
- Testing a file and then acting on it leaves a window in which the file can
  change. Prefer a single atomic operation over test-then-act.

## Downloads

`curl ... | bash` gives the remote server a shell on the host, and a partial
download can execute a truncated command. Download to a file, verify a
checksum or signature, inspect, then run.

## References

- Source: <https://owasp.org/www-community/attacks/Command_Injection>
