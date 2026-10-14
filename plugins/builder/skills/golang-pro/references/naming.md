# Naming (golang-pro)

Checklist distilled from Effective Go ("Names") and the Google Go Style
Guide (decisions on package names, repetition, initialisms, getters,
receivers, variables). Enforced where automatable by `staticcheck`
(ST1003), `revive`, and `predeclared`.

## Packages
- Lowercase, single word, no underscores: `tabwriter`, `base64`. The name is
  the base name of the source directory (`encoding/base64` → `base64`).
- Never stutter: the exported symbol must not repeat the package name.
  `bufio.Reader` not `bufio.BufReader`; `ring.New` not `ring.NewRing`.
- Avoid uninformative names: `util`, `utility`, `common`, `helper`, `model`.
- Avoid names likely to be shadowed by locals in callers.
- Test doubles live in a helper package named `<pkg>test` (`creditcardtest`):
  a single double is `Stub`; behavior-named doubles read as sentences
  (`AlwaysCharges`, `AlwaysDeclines`); several types become `StubService`,
  `StubStoredValue`.
- Black-box tests use `<pkg>_test` (e.g. `linkedlist_test`).

## Identifiers
- MixedCaps everywhere, no underscores: `MaxLength`, `maxLength`. Never
  `MAX_LENGTH`, `max_length`, `kMaxBufferSize` — even for constants.
- Initialisms keep uniform case (each initialism all-one-case; different
  initialisms in one name need not match each other):
  `ID`/`id` (never `Id`), `DB`/`db`, `URL`/`url`, `xmlAPI`, exported `IOS`
  vs unexported `iOS`, exported `GRPC` vs unexported `gRPC`, `Txn` not `TXN`.
- Getters take no `Get` prefix: field `owner` → method `Owner()`, setter
  `SetOwner()`. Exception: the concept literally uses "get" (HTTP GET).
  Expensive or remote calls signal cost: `Compute`, `Fetch`.
- One-method interfaces are method name + `-er`: `Reader`, `Writer`,
  `Formatter`, `CloseNotifier`. Never reuse a canonical method name
  (`Read`, `Write`, `Close`, `Flush`, `String`) unless the signature and
  meaning match exactly; conversely, if your method means the same as a
  well-known one, use that name (`String`, not `ToString`).
- Receivers: 1–2 letters, an abbreviation of the type, consistent across
  every method of the type. `func (t Tray)`, `func (s *Scanner)`. Never
  `this`/`self`; omit the name when unused.
- Error variables: sentinels are package-level `var ErrXxx = errors.New(...)`
  (prefix `Err`); error types take the suffix `Error` (`errname` enforces).
  Document what each sentinel means.
- Error strings: lowercase, no trailing punctuation, identify origin:
  `"image: unknown format"`. Never distinguish errors by string matching.
- Variables: name length proportional to scope (1–2 chars is fine for a
  5-line scope; multi-word past ~25 lines). Omit the type from the name
  (`users`, not `userSlice`) unless two same-concept values share scope
  (`ageString` vs `age`). No invented abbreviations (`Sandbox`, not `Sbx`).
  `i` for indices, `r`/`w` for reader/writer-ish, `err` for errors.
- Functions: noun-like when returning something (`JobName`), verb-like when
  doing something (`WriteDetail`). Don't repeat parameter, receiver, or
  package names (`Parse`, not `ParseYAMLConfig`, in `package yamlconfig`).
  Type-disambiguated siblings take the type suffix (`ParseInt`/`ParseInt64`);
  the primary form stays unadorned (`Marshal`/`MarshalText`).
