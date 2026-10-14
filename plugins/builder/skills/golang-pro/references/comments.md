# Comments (golang-pro)

Distilled from the Google Go Style Guide (Godoc sections) and enforced by
`revive` (`exported`, `package-comments`), `godot`, and gofumpt's comment
rules.

## Doc comments
- Every exported identifier gets a doc comment that is a full sentence
  ending in a period (`godot`) and begins with the identifier's name:
  `// Compile parses a regular expression and returns, if successful, a
  Regexp object ...`.
- Every package gets a package comment (`revive` `package-comments`),
  placed before the `package` clause. Document package-wide error
  conventions there when they apply broadly.
- Explain *why*, not *what*. Don't restate the code and don't document the
  obvious — read-only operations are assumed concurrency-safe, mutating
  ones are assumed not to be.
- Document the non-obvious: unusual concurrency behavior, cleanup
  obligations (`Close`/`Stop`), special `Context` demands, significant
  sentinel errors and error types (noting pointer vs value receivers).

## Godoc mechanics
- Blank `//` line between paragraphs; two-space indent for verbatim
  (preformatted) blocks.
- Runnable examples are `ExampleXxx` functions with `// Output:` comments —
  they compile and run as tests (`testableexamples`).

## Comment hygiene
- Non-directive comments start with whitespace: `// Foo`, never `//Foo`
  (gofumpt enforces this).
- Directives (`//go:build`, `//go:generate`, `//go:embed`) must be valid;
  `go vet`'s `directive`/`buildtag` analyzers and
  `gocheckcompilerdirectives` check them.
- `//nolint` directives must name the specific linter and carry a reason
  (`nolintlint`); blanket `//nolint` is banned.
