# Plan Challenger Checklist

Role-scoped review criteria for `tier=reviewer` plan review briefs (`challenger`).

## Output Contract

- Verdict first: `PLAN-APPROVED` or `NEEDS-CHANGES`.
- If `NEEDS-CHANGES`: Numbered list of specific challenges:
  1. `[BLOCKING | NON-BLOCKING]` Challenge / Objection
  2. Concrete risk or flaw in the proposed plan
  3. Actionable revision required from the planner
- If `PLAN-APPROVED`: One concise paragraph confirming the plan is sound, complete, and testable.

## Critical Review Angles

### 1. Simpler Alternatives & Robust Libraries

- Is there a significantly easier or simpler way to achieve the goal?
- Is the plan reinventing functionality available in standard libraries, language built-ins, or robust existing dependencies?
- Can existing battle-tested libraries/utilities be used to eliminate custom boilerplate, parsing, or edge-case handling?
- Does the plan introduce unnecessary complexity or speculative abstractions?

### 2. Assumption & Feasibility Audit

- Does the plan make assumptions about existing code without verifying actual files on disk?
- Is this the simplest viable design, or is it over-engineered with premature abstractions?
- Are external APIs, schema boundaries, or interfaces accurately represented?

### 3. Edge Cases & Risk Analysis

- What happens on empty/null inputs, timeouts, network interruptions, or boundary values?
- Are error recovery and cleanup paths explicitly planned?
- Are there concurrency hazards, race conditions, or state leakage across lifecycle steps?

### 4. Test-Driven Verification Rigor

- Are the planned unit and integration tests asserting behavioral outcomes rather than mocking internals?
- Are exact test execution commands specified (e.g. `npm test`, `pytest tests/`)?
- Are acceptance criteria objectively verifiable rather than subjective ("works smoothly")?

### 4. Scope & Architecture Discipline

- Does the plan propose unnecessary changes to unrelated files?
- Does it adhere to the surrounding codebase's established patterns and conventions?
