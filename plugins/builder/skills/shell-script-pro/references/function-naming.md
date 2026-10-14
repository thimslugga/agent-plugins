# Shell Script Function Naming Conventions

## Technical rules (what bash allows)

- Allowed characters: letters, numbers, underscores. Symbols like `+ - . / = : ? @` are legal in some positions — avoid them anyway.
- Never start a function name with a number.
- Avoid symbols with special shell meaning: `! | & ; ( ) < >`.

## Style (Google Shell Style Guide + project standard)

- The `function` keyword is optional; use it consistently within a project.
- `snake_case` only: all lowercase, words separated by underscores.
  - Good: `backup_database`, `clean_log_files`
  - Bad: `backupDatabase` (camelCase), `BackupDatabase` (PascalCase)
- Start with a descriptive verb naming exactly what the function does: `get_user_input`, `render_template`.
- Parentheses required after the name, no space before them: `my_func() {`.
- Opening brace on the same line as the function name.

## Namespacing and prefixes

Bash has no native namespaces; use prefixes to structure larger scripts and libraries.

| Convention | Pattern / Example | Purpose |
|---|---|---|
| Pseudo-namespaces | `git::clone`, `aws::upload` | Separate modules/libraries within a project |
| Private functions | `__internal_helper` | Internal-only; called by other functions, not by users |
| 
| Tab completion | `_my_cli_complete` | Completion helpers (single underscore = system/completion convention) |

**Note: Standalone scripts with a handful of functions do not need `::` namespaces.**
**Note: Google recommends `::` namespacing for libraries, but warns that colons break interactive tab-completion — fine in scripts and libraries, avoid in completion contexts.**

## Preferred names

Before inventing a name, check the curated lists: `references/function-names.txt`
for functions, `references/variable-names.txt` for constants and variables.
Prefer a name from the list; only coin a new one when nothing there fits, and
follow the rules above when you do.

## References

- https://tldp.org/LDP/abs/html/functions.html
- https://tldp.org/LDP/abs/html/complexfunct.html
- https://tldp.org/LDP/abs/html/localvar.html
- https://tldp.org/LDP/abs/html/recurnolocvar.html
