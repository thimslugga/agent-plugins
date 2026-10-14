# Framework conventions

PEP 8 and this skill's standard are the base. When working inside a
framework, its idioms layer on top — match the codebase you're in, not just
the generic rules. Django is the worked example; apply the same principle
(learn the framework's idioms first) to Flask, FastAPI, and others.

## Django

- **Models:** PascalCase classes, snake_case fields and methods. The inner
  config class is always named `Meta`.
- **Views:** snake_case for function-based views, PascalCase for
  class-based views.
- **URLs:** snake_case pattern names (`name='article_list'`); the file is
  always `urls.py`.
- **Apps:** lowercase, preferably single words (`blog`, `payments`).
- **Templates:** lowercase with underscores or hyphens
  (`article_list.html`); template tags/filters are snake_case.
- **Forms and serializers:** PascalCase with a descriptive suffix
  (`ContactForm`, `ArticleSerializer`); managers/querysets likewise
  (`PublishedManager`, `ArticleQuerySet`).
- **Settings:** UPPER_SNAKE_CASE, same as constants (`ALLOWED_HOSTS`,
  `AUTH_USER_MODEL`); custom settings follow the same pattern.
