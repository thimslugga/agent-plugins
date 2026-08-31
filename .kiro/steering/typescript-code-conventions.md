---
inclusion: fileMatch
fileMatchPattern: ["**/*.ts", "**/*.tsx", "**/tsconfig.*.json"]
---

# TypeScript Code Conventions

## File Extensions: .ts vs .tsx

- `.tsx` — files that render JSX (React components, pages, panels, modals, split-pane views)
- `.ts` — pure TypeScript with no React rendering: helpers, utilities, data transformers, constants, types, enums, codegen output
- If a file has no JSX but uses React hooks (useState, useMemo, useCallback, useEffect) or makes API calls, extract it as a **custom hook** (`use*.ts`) — hooks are `.ts` not `.tsx` because they return data, not JSX
- Never put standalone utility functions (formatCurrency, parseDate, buildFilter) in `.tsx` files — keep them in dedicated `.ts` helper/util modules
- Test files follow their source: `component.test.tsx` for components, `helper.test.ts` for utilities

## TypeScript / React Code Style

- Use kebab-case for file names, PascalCase for components
- Define components using the `function` keyword (not arrow functions)
- Prefer functional components with TypeScript interfaces/types
- Use `useCallback` for callback functions passed as props or used in event handlers
- Use `useMemo` for expensive computations
- Avoid inline function definitions in JSX unless trivially simple
- Implement proper cleanup in useEffect hooks (isCancelled flags, abort controllers)
- Only include used dependencies in useEffect dependency arrays
- Prefer `||` over `??` when empty strings should also trigger fallback values
- Keep components under ~500 lines; extract sub-panes, utilities, and hooks into separate files
- Document non-obvious prop contracts with TSDoc (especially props that change data-fetching behavior)
- Add explicit typing — avoid `any`. Always add explicit return types to functions and callbacks (e.g. `function foo(): string` not just `function foo()`)
- Prefer functional composition over imperative loops
- Use proper key props in lists (avoid using index as key)

## Error Handling in UI

- Don't swallow errors with try/catch or .then/.catch in UI component code — route errors through the app's designated error-handling path (error callbacks, error states, notification helpers)
- Don't `console.log`/`console.error` in UI code — surface errors to the user through the app's notification pattern

## State Management

- Normalize state structure — avoid deeply nested data
- Use selectors to encapsulate state access
- Separate concerns by feature — no monolithic slices

## Form Validation

- Validate forms schema-first (a schema library as the single source of validation truth)
- Implement proper error messages for validation failures

## Comments — CRITICAL, ALWAYS FOLLOW

- You MUST NOT add comments that describe what code does — variable names and structure should convey intent
- You MUST NOT add comments within methods — refactor unclear code instead
- You MUST NOT narrate implementation steps in comments (e.g. "// Fetch the data", "// Check if valid", "// Return the result")
- Inline comments are ONLY acceptable as a brief "why" (1-2 lines max) when the reason is non-obvious
- TSDoc comments should be at most 2 lines — a single sentence for purpose and one for a non-obvious constraint. If it needs more, the code needs refactoring.
- Put detailed explanations in the module-level TSDoc, not inline

## Performance

- Watch for O(n²) algorithms that could be O(n)
- Identify missed caching opportunities
- Check for memory leaks or excessive allocations in effects

## Testing

- Use Vitest for TypeScript, JUnit Jupiter for Java
- Don't mock library internals — only mock boundaries (APIs, services)
- Dev-only utilities still need tests for edge cases (caching, concurrency, expiry)
