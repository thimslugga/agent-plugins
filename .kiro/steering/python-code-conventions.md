---
inclusion: fileMatch
fileMatchPattern: ["**/*.py", "**/*.pyi", "**/pyproject.toml"]
---

# Python Code Conventions

## Project Structure

A typical Python project structure:

```text
project/
├── pyproject.toml      # Project metadata and dependencies
├── README.md
├── src/
│   └── package_name/
│       ├── __init__.py
│       ├── main.py
│       └── utils.py
├── tests/
│   ├── __init__.py
│   ├── test_main.py
│   └── test_utils.py
└── .gitignore
```

## Tooling (from `pyproject.toml`)

| Tool     | Config                                                                    | Command                               |
| -------- | ------------------------------------------------------------------------- | ------------------------------------- |
| **ruff** | rules E,F,W,I; ignores E721; target py312                                 | `ruff check .` / `ruff check --fix .` |
| **mypy** | `disallow_untyped_defs=true`, `no_implicit_optional=true`, excludes tests | `mypy doubleml`                       |
| **prek** | ruff + trailing whitespace + debug statements                             | `pre-commit run --all-files`          |

## Package Management and Dependencies

- **Prefer uv** (`uv`) for Python package management and virtual environment creation.
  - Use `uv venv` for virtual environment creation
  - Use `uv pip install` for package installation
  - Use `uv tool install` for tool installation to `~/.local/bin`
  - Use `uv pip compile` for generating locked dependency files

```bash
# Create a virtual environment (python 3.12)
uv venv .venv --clear --python 3.12 --seed

# Install packages
uv pip install requests

# Install from requirements
uv pip install -r requirements.txt

# Compile/lock dependencies
uv pip compile requirements.in -o requirements.txt
```

- Define dependencies in `pyproject.toml` using modern PEP 621 format.
- Separate development dependencies from production dependencies.
- Pin versions in lock files for reproducible builds.

```toml
# pyproject.toml

[project]
name = "my-project"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "httpx>=0.25.0",
    "pydantic>=2.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "ruff>=0.1.0",
]

...
```

## Code Formatting and Linting

- **Use Ruff** as the primary linter and formatter.
  - Ruff is extremely fast and replaces multiple tools (flake8, isort, black, etc.).
  - Configure via `pyproject.toml`.

```toml
# Configure in pyproject.toml
[tool.ruff]
line-length = 100
target-version = "py312"  # Adjust based on your project's minimum Python version

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "B",    # flake8-bugbear
    "C4",   # flake8-comprehensions
    "UP",   # pyupgrade
    "SIM",  # flake8-simplify
]
ignore = ["E501"]  # Line length handled by formatter

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.mypy]
strict = true
```

Run with:

```bash
ruff check --fix .  # Lint and auto-fix
ruff format .       # Format code
```

## Type Hints

type hints improve code clarity, maintainability, and enable better tooling support.

- All functions require complete type annotations including return types.
- Annotate function parameters, return types, and class attributes.
- Use `typing` module constructs (`Optional`, `Union`, `List`, `Dict`, `Callable`, etc.) for complex types.
- For Python 3.10+, prefer the built-in union syntax (`X | Y`) and built-in generics (`list[str]` instead of `List[str]`).
- Use `-> None` for functions without return value
- Use `Optional[X]` or `X | None` (with `__future__` import) for nullable params
- Never suppress valid errors with `# type: ignore` — fix the type instead

```python
def calculate_total(items: list[float], tax_rate: float = 0.0) -> float:
    """Calculate the total price including tax."""
    subtotal = sum(items)
    return subtotal * (1 + tax_rate)
```

Configure strict type checking for production code:

```toml
# pyproject.toml
[tool.mypy]
python_version = "3.12"  # Adjust based on your project's minimum Python version
strict = true
warn_return_any = true
warn_unused_ignores = true
disallow_untyped_defs = true
disallow_incomplete_defs = true

[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false
```

Alternative: Use `pyright` for faster checking.

```toml
[tool.pyright]
pythonVersion = "3.12"
typeCheckingMode = "strict"
```

## Naming Convetions

- Use meaningful names for variables, functions, classes, and modules.
- Names should reveal intent.
- Use `snake_case` for functions and variables.
- Use `PascalCase` for classes.
- Use `UPPER_SNAKE_CASE` for constants.

## Naming Conventions

| Element              | Convention            | Example                                             |
| -------------------- | --------------------- | --------------------------------------------------- |
| Modules              | `snake_case`          | `double_ml_plr.py`                                  |
| Classes              | `PascalCase`          | `DoubleMLPLR`                                       |
| Methods/functions    | `snake_case`          | `fit_nuisance_models()`                             |
| Private methods      | `_leading_underscore` | `_nuisance_est()`                                   |
| Class variables      | `_UPPER_SNAKE`        | `_LEARNER_SPECS`                                    |
| Constants            | `UPPER_SNAKE`         | `DEFAULT_N_FOLDS`                                   |
| Statistical notation | Conventional names    | `theta`, `se`, `psi_a`, `psi_b`, `n_obs`, `n_folds` |

Follow PEP 8 with emphasis on clarity over brevity.

**Files and Modules:**

```python
# Good: Descriptive snake_case
user_repository.py
order_processing.py
http_client.py

# Avoid: Abbreviations
usr_repo.py
ord_proc.py
http_cli.py
```

**Classes and Functions:**

```python
# Classes: PascalCase
class UserRepository:
    pass

class HTTPClientFactory:  # Acronyms stay uppercase
    pass

# Functions and variables: snake_case
def get_user_by_email(email: str) -> User | None:
    retry_count = 3
    max_connections = 100
```

**Constants:**

```python
# Module-level constants: SCREAMING_SNAKE_CASE
MAX_RETRY_ATTEMPTS = 3
DEFAULT_TIMEOUT_SECONDS = 30
API_BASE_URL = "https://api.example.com"
```

## Functions

- Functions should be small and do one thing well.
- Function names should describe the action being performed.
- Prefer fewer arguments in functions—ideally no more than two or three.
- Use keyword arguments for optional parameters to improve readability.

## Additional Best Practices

- Use dataclasses or Pydantic models for structured data.
- Prefer composition over inheritance.
- Use `pathlib.Path` instead of string paths.
- Use f-strings for string formatting.
- Use context managers for resource management.
- Write idiomatic Python—leverage built-in functions and standard library.

## Comments and Documentation

- Strive to make code self-explanatory.
- Only use comments when necessary, as they can become outdated.
- When comments are used, they should add useful information not readily apparent from the code.

### Docstrings (NumPy Style)

- Write docstrings (NumPy style) for all public modules, classes, and functions.
- Required sections: **summary**, **Parameters**, **Returns**. Optional: **Raises**, **Examples**, **Notes**.

## Error Handling

- Properly handle errors and exceptions to ensure robustness.
- Use exceptions rather than error codes for handling errors.
- Be specific with exception types—avoid bare `except:` clauses.
- Use context managers (`with` statements) for resource management.

```python
def read_config(path: Path) -> dict[str, Any]:
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        raise ConfigurationError(f"Config file not found: {path}")
    except json.JSONDecodeError as e:
        raise ConfigurationError(f"Invalid JSON in config: {e}")
```

## Testing

- **Use pytest** as the testing framework.
- Write tests alongside code in a `tests/` directory or use inline `_test.py` suffix.
- Use fixtures for shared setup and teardown.
- Aim for high test coverage, especially for critical paths.
- Use `pytest-cov` for coverage reporting.

```bash
# Run tests
pytest

# Run with coverage
pytest --cov=src --cov-report=term-missing
```

```python
# Example test
def test_calculate_total() -> None:
    result = calculate_total([10.0, 20.0], tax_rate=0.1)
    assert result == 33.0
```

## HTTP Requests

- **Prefer `httpx`** over `requests` for making HTTP requests.
  - `httpx` supports async/await natively.
  - API is similar to `requests` for easy migration.
  - Better timeout handling and HTTP/2 support.

```python
import httpx

def fetch_data(url: str) -> dict[str, Any]:
    response = httpx.get(url, timeout=30.0)
    response.raise_for_status()
    return response.json()
```

## Security

- Consider security implications of the code.
- Implement security best practices to protect against vulnerabilities.
- Never hardcode secrets—use environment variables or secret managers.
- Validate and sanitize all external inputs.
- Keep dependencies updated to patch known vulnerabilities.

## Verification Checklist

Before completing any task, run:

```bash
black .                    # Format
ruff check --fix .         # Lint + auto-fix
mypy doubleml              # Type check
pytest -m ci               # Tests
```

Check:

- [ ] All functions have type hints and return types
- [ ] File starts with a module-level docstring (one sentence, matching file type pattern)
- [ ] Public functions/classes have NumPy-style docstrings
- [ ] Learners validated with `_check_learner()`, cloned with `clone()` before fitting
- [ ] Score elements named `psi_a`/`psi_b`, shapes are `(n_obs,)`
- [ ] No `print()`, `breakpoint()`, or debug statements
- [ ] No magic numbers — use named constants
- [ ] Sample splitting uses `DoubleMLResampling`, not raw `KFold`

## Philosophy

### The Zen of Python

Refer to **The Zen of Python** (PEP 20) as a guiding philosophy for writing Pythonic code. Access it by running:

```python
import this
```

## References

- [PEP 20 – The Zen of Python](https://peps.python.org/pep-0020/)
- [PEP 8 – Style Guide for Python Code](https://peps.python.org/pep-0008/)
- [PEP 484 – Type Hints](https://peps.python.org/pep-0484/)
- [UV Documentation](https://github.com/astral-sh/uv)
- [Ruff Documentation](https://docs.astral.sh/ruff/)
- [pytest Documentation](https://docs.pytest.org/)
