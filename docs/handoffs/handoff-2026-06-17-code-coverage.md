# Handoff: Code Coverage — pcov + 80% Threshold + CI Job (Issue #13)

**Date:** 2026-06-17
**Branch:** `master` (all merged)
**Repo:** `psswid/triageflow-docs` (parent) + nested `backend/` + `frontend/` (separate git repos)

## Session Summary

Closed Issue #13 — installed pcov in Docker, configured Clover + text coverage reports in phpunit.dist.xml, added 80% coverage threshold enforcement in CI via clover.xml parsing, with artifact upload. Backend-only changes.

## What Was Built

### Backend — 3 files modified

**`phpunit.dist.xml`** (lines 29-31):
- Added `<clover outputFile="var/coverage/clover.xml"/>` 
- Added `<text outputFile="php://stdout" showOnlySummary="true"/>`
- Three reports now produced: html (local), text (stdout summary), clover (CI parsing)

**`Dockerfile`** (lines 10-14):
- Added `$PHPIZE_DEPS` for build dependencies
- `pecl install pcov` — compiled coverage driver (lightweight, no xdebug overhead)
- `docker-php-ext-enable pcov`
- `apk del $PHPIZE_DEPS` — clean up build deps, keep image lean

**`.github/workflows/ci.yml`** (coverage step):
- Changed `php bin/phpunit` → `php bin/phpunit --configuration phpunit.dist.xml --coverage-clover`
- Added "Check coverage threshold (≥80%)" step — inline `php -r` script that:
  - Guards with `file_exists()` (fails with clear error if clover.xml missing)
  - Parses `clover.xml` with `simplexml_load_file()`
  - Extracts `coveredstatements` / `statements` from `<metrics>` element
  - Exits 1 if below 80%
- Added `actions/upload-artifact@v4` to persist `var/coverage/clover.xml`

### Key Design Decision: CI-Level Threshold (ADR-0009)

PHPUnit 11.5.55 XSD does **not** support `threshold="80"` on the `<phpunit>` element. The attribute appears in some docs but fails XSD validation. Crap4J threshold measures CRAP score (complexity × coverage), not statement coverage. Enforcing at CI level via XML parsing decouples from PHPUnit version quirks and works with any coverage driver.

### Tests Updated

- `OpenRouterClientTest.php` — added `coverage: null` to satisfy constructor (logger param not affected)
- No regressions — 252/252 pass

## Design Decisions

All documented in ADR-0009 (`docs/adr/0009-code-coverage-ci-threshold.md`). Key points:
- **pcov over xdebug** — lighter, purpose-built for coverage, no runtime overhead in non-coverage mode
- **CI-level enforcement** — not PHPUnit XML (XSD limitation of PHPUnit 11.x)
- **Clover format** — machine-parseable XML (not HTML/text), compatible with any CI platform
- **Threshold at 80%** — matches project convention in agents.md and .opencode/config.json

## Verification

| Check | Result |
|-------|--------|
| `php bin/phpunit` | ✅ 252/252 pass (893 assertions) |
| `php bin/phpunit --coverage-clover` | ✅ Produces `var/coverage/clover.xml` with metrics |
| `npx vitest run` | ✅ 146/146 pass (24 files) |
| `npx eslint src/` | ✅ 0 errors |
| `npx tsc --noEmit` | ⚠️ 7 pre-existing TS errors (unrelated) |
| `phpstan analyse` | ✅ Level 5, 0 errors |

## Commits

**Backend** (on `master`, in nested `backend/` repo):
- `c741e11` — ci: add code coverage enforcement with pcov and 80% threshold

**Docs** (on `master`, parent repo):
- `4803c00` — docs: add code coverage implementation plan
- `c3ed9de` — docs: add ADR-0009 for CI-level coverage enforcement + raw_log entry

## Open Issues

| # | Title | Status |
|---|-------|--------|
| 14 | E2E Test Suite: User Journey — registration, triage interview, outcomes | `ready-for-agent` |
| 15 | E2E Test Suite: Admin Journey — dashboard, synthetic cases, impersonation | `ready-for-agent` |
| 16 | Accessibility: Focus management, ARIA labels, live regions | `ready-for-agent` |

No other open issues. #11 (accessibility audit) and #12 (rate limiter) are closed.

## Refs

- **Plan:** `docs/superpowers/plans/2026-06-17-code-coverage-pcov-80-threshold.md`
- **ADR:** `docs/adr/0009-code-coverage-ci-threshold.md`
- **Raw log:** `raw_log.md` (entry for 2026-06-17)
- **Issue #13:** https://github.com/psswid/triageflow-docs/issues/13
- **Handoff from prev session:** `docs/handoffs/handoff-2026-06-16-openrouter-rate-limiter.md`

## Context Files to Load

For the next sprint, the agent should load:
- `CONTEXT.md` — domain language and glossary
- `agents.md` — architecture decisions, project structure
- `backend/agents.md` — backend conventions, testing patterns
- `frontend/agents.md` — frontend conventions, component patterns
- `docs/handoffs/handoff-2026-06-17-code-coverage.md` — this session's context
- `raw_log.md` — full development log
- `docs/tools-scenarios-backend.md` — backend scenario references
- `docs/tools-scenarios-frontend.md` — frontend scenario references

## Suggested Skills

- `brainstorming` — for creative work like UX/accessibility polish
- `writing-plans` — create formal implementation plans for new issues
- `grill-with-docs` — stress-test planned features against existing domain model and codebase
- `subagent-driven-development` — execute multi-task plans with quality gates
- `verification-before-completion` — verify tests pass before claiming completion
- `finishing-a-development-branch` — merge/pr/cleanup workflow
- `context7` — fetch up-to-date docs for Playwright or external libraries
- `find-skills` — discover additional skills for the task at hand
