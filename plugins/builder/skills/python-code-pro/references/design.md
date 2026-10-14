# Function and class design, error handling

## Functions

- One function, one responsibility. Names describe the action performed.
- At most 5 parameters (enforced: `PLR0913`); prefer two or three. Beyond
  that, group related parameters into a dataclass.
- Keyword arguments for optional parameters — call sites stay readable.
- **Never** use mutable default arguments (enforced: `B006`); default to
  `None` and build inside.
- Return early to reduce nesting.

## Classes

- Prefer composition over inheritance.
- Dataclasses for simple data containers; Pydantic models for validated,
  structured data.
- Keep `__init__` simple — no complex logic, no I/O.
- One responsibility per class. Don't add methods "just in case".
- `@property` for computed attributes, not `get_*` methods.

## Error handling

- Catch specific exceptions — never bare `except:` (enforced: `BLE`, `E722`).
- **Never** silently swallow an exception: log it or re-raise. A bare
  `except SomeError: pass` is a bug unless the pass carries a comment
  explaining why swallowing is correct.
- Prefer exceptions over error codes and sentinel returns.
- Wrap low-level errors at API boundaries into domain exceptions with
  context (`raise ConfigError(f"...: {path}") from e`), don't leak
  `FileNotFoundError`/`JSONDecodeError` to callers.
- Resource management goes through context managers (enforced: `SIM115`
  for `open()`); never rely on explicit `close()`.
