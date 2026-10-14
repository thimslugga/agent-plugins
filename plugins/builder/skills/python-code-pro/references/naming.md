# Naming conventions

Case conventions are enforced mechanically by ruff's `N` (pep8-naming)
rules; this reference covers the judgment calls they can't make.

| Target    | Convention      | Example                          |
|-----------|-----------------|----------------------------------|
| Classes   | PascalCase      | `CustomerAccount`, `HTTPClient`   |
| Functions | snake_case      | `calculate_total`, `get_user`     |
| Methods   | snake_case      | `process_data`                   |
| Variables | snake_case      | `user_name`, `total_count`       |
| Constants | UPPER_SNAKE     | `MAX_RETRIES`, `DEFAULT_TIMEOUT` |
| Modules   | snake_case      | `user_repository`, `http_client` |
| Packages  | lowercase       | `mypackage`                      |

- **No camelCase:** `myVariable` is a JavaScript habit; Python uses
  PascalCase for classes and snake_case for everything else.
- **Acronyms:** in PascalCase capitalize only the first letter
  (`HttpResponse`, `XmlParser`); in snake_case keep them lowercase
  (`parse_html`, `http_client`).
- **Descriptive over clever:** names reveal intent. Short names for short
  scopes (`i` as a loop counter is fine); longer scopes earn longer names.
- **Never** use `l`, `O`, `I` as single-letter names — they read as digits.
  Single characters are fine only for tight scopes: loop counters (`i`, `j`,
  `k`), coordinates (`x`, `y`, `z`), `except Exception as e`.
- **Booleans** read as predicates: `is_valid`, `has_permission`, `can_edit`.
- **Private members:** `_single_leading_underscore` marks internal use
  (convention only); `__double_leading_underscore` triggers name mangling —
  use sparingly, not as a default; `trailing_underscore_` avoids keyword
  clashes (`class_`).
- **Dunder methods** (`__init__`, `__str__`, `__len__`) are Python-defined —
  implement the ones you need, but never invent your own `__dunder__` names.
- **No abbreviations** in module names: `user_repository.py`, not
  `usr_repo.py`.
- **No emoji** (or unicode that emulates emoji) in code. The only exception
  is tests exercising multibyte characters.
