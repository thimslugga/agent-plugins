# Design (golang-pro)

Distilled from Effective Go, the go1.13 errors blog post, and the Google Go
Style Guide. Enforced where automatable by `errcheck`, `errorlint`,
`errname`, `err113`, `nilerr`, `nilnil`, `ireturn`, `interfacebloat`,
`revive` (`indent-error-flow`), and `govet`.

## Errors are values
- Return `error`; don't panic for normal error handling. Panic is for the
  truly unrecoverable or provably impossible. Library code must not leak
  panics to callers — convert internal panics to errors at the package
  boundary (the `regexp.Compile` pattern).
- `MustX` helpers (`MustParse`, `template.Must`) may panic, but only for
  package-init-time setup with constant inputs. In tests, prefer `t.Fatal`
  variants. In `main`, `log.Exit` for fatal startup errors (it calls
  `os.Exit`; deferred functions do not run).
- Sentinels: `var ErrNotFound = errors.New("not found")`. Callers check
  with `errors.Is`, never `==` on a wrapped chain and never string matching.
- Wrap with `%w` only to expose the underlying error for programmatic
  inspection — wrapping makes the wrapped error part of your API. Use `%v`
  for annotation-only context. At system boundaries (RPC/IPC/storage),
  translate into a canonical error space instead of leaking internals.
  `%w` goes last: `fmt.Errorf("open config: %w", err)`.
- Prefer `errors.As` over type assertions on chains; implement
  `Unwrap() error` on custom error types carrying a cause. Don't return the
  bare sentinel when the documented contract says "wraps X" — always wrap,
  so callers must use `errors.Is`.
- Never `return nil, nil`. Return a valid zero value with the nil error.
- Check every error (`errcheck`). Deliberate ignores need a justified
  `//nolint:errcheck`; `errgroup` for fan-out where only the first error
  matters.
- Document the error contract: which sentinels/types are returned, whether
  an error is a pointer receiver (it matters for `errors.Is`/`As`), and
  package-wide conventions in the package doc.

## Interfaces
- Small: 1–3 methods (`interfacebloat` caps at 10; treat that as a fire
  alarm, not a target). Design for the consumer, declared at the consumer
  side; keep unexported if package-internal.
- Don't invent interfaces until a real need exists. Up-front
  "service"/"repository" abstractions are a smell; don't wrap RPC clients
  in hand-rolled interfaces just for tests.
- Accept interfaces, return concrete types (`ireturn` enforces the second
  half). Exceptions: `error`, and the type that exists only to implement
  the interface (export the interface, keep the type unexported, constructor
  returns the interface, e.g. `hash.Hash32`).
- Document the interface contract: semantics, edge cases, expected errors,
  concurrency safety.

## Packages and dependencies
- A package is a directory; its name is the access path. Keep APIs small
  and focused; one concept per package. Split when the package name no
  longer describes everything in it.
- Least mechanism: core language → stdlib → existing shared library →
  new dependency. Minimize dependencies, implicit and explicit; don't
  depend on undocumented or internal behavior.

## Concurrency
- Share memory by communicating; don't communicate by sharing memory.
  Channels transfer ownership; mutexes are fine for simple cases.
- Specify channel direction (`<-chan int`, `chan<- int`) — the compiler
  then catches close/send mistakes.
- Goroutine lifetimes must be obvious: scope concurrency to a function,
  use `context.Context` + `sync.WaitGroup`, and never start a goroutine
  without knowing how it stops. A goroutine blocked on a channel is never
  garbage-collected.
- `ctx context.Context` is the first parameter, never stored in structs,
  never placed in option structs.
- Concurrency safety is assumed for read-only operations and not assumed
  for mutating ones — document only the non-obvious cases.

## Signatures and values
- Keep argument lists short; past ~3–4 parameters use an option struct
  (exported iff it appears in an exported API) or functional options
  (`WithX(...)`) with last-wins conflict semantics.
- Pass values, not pointers, for small arguments (`string`, slices,
  interfaces — never `*io.Reader`). Pointer receivers when mutating, when
  the struct contains a lock or `noCopy`, or for large/growing structs.
  Keep the receiver type consistent per type.
- Prefer `:=` for non-zero initialization; use the zero value via `var`
  for types that are ready-to-use empty (`var buf bytes.Buffer`).
  `new(T)` / `&T{}` for pointer zero values.
- Guard-clause style: no `else` after `return`, `break`, or `continue`
  (`indent-error-flow` enforces this).
