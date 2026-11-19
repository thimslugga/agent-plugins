# Shell Script Function Naming Conventions

## Technical rules (what bash allows)

- Use letters, numbers, and underscores for portable function names. Bash libraries may use `::` as described below.
- Never start a function name with a number.
- Avoid symbols with special shell meaning: `! | & ; ( ) < >`.

## Style (Google Shell Style Guide + project standard)

- The `function` keyword is optional; use it consistently within a project.
- Use `snake_case`: all lowercase, words separated by underscores. In libraries, apply this rule to both parts of an optional `library_name::function_name` namespace.
  - Good: `backup_database`, `clean_log_files`
  - Bad: `backupDatabase` (camelCase), `BackupDatabase` (PascalCase)
- Start with a descriptive verb naming exactly what the function does: `get_user_input`, `render_template`.
- Parentheses required after the name, no space before them: `my_func() {`.
- Opening brace on the same line as the function name.

## Namespacing and prefixes

Bash has no native namespaces. Standalone scripts use plain function names such as `err()`, `cleanup()`, and `main()`.
Do not prefix these functions with the script name, regardless of script size.
Libraries may prefix functions with the library or package name, using `::` as the delimiter, to avoid collisions when sourced.

| Convention | Pattern / Example | Purpose |
|---|---|---|
| Library namespaces | `git::clone`, `aws::upload` | Separate libraries/packages loaded into the same shell |
| Private functions | `__internal_helper` | Internal-only; called by other functions, not by users |
| Tab completion | `_my_cli_complete` | Completion helpers (single underscore = system/completion convention) |

Avoid colon-delimited names in interactive completion functions; they do not work well in that context.

```bash
# Standalone script
err() {
  printf '%s\n' "$*" >&2
}

# Function in a sourced library
mypackage::my_func() {
  printf '%s\n' "$1"
}
```

## Preferred names

Before inventing a name, check the curated lists: `references/function-names.txt`
for functions, `references/variable-names.txt` for constants and variables.
Prefer a name from the list; only coin a new one when nothing there fits, and
follow the rules above when you do.

## References

- https://google.github.io/styleguide/shellguide.html#s7.1-function-names
- https://tldp.org/LDP/abs/html/functions.html
- https://tldp.org/LDP/abs/html/complexfunct.html
- https://tldp.org/LDP/abs/html/localvar.html
- https://tldp.org/LDP/abs/html/recurnolocvar.html
