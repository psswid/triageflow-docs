# Handoff: Structured Logging + Observability (Issue #10)

**Date:** 2026-06-13
**Branch:** `master` (all merged)
**Repo:** `psswid/triageflow-docs` (parent) + nested `backend/` + `frontend/` (separate git repos)

## Session Summary

Implemented Issue #10 — structured logging with correlation IDs, handler timing/status tracking, and frontend lint cleanup. Complete backend/frontend implementation with tests.

## What Was Built

### Backend — Correlation ID Pipeline (3 new files, 8 modified)

**CorrelationIdProcessor** (`backend/src/Shared/Infrastructure/Logging/CorrelationIdProcessor.php`):
- Monolog processor registered via `monolog.processor` tag (all channels/handlers)
- `__invoke(LogRecord $record): LogRecord` — sets `$record->extra['correlation_id']`
- Static `setCorrelationId()` for external injection (subscriber sets on HTTP, handlers set in worker context)
- Falls back to `'no-request'` when none is set

**CorrelationIdSubscriber** (`backend/src/Shared/Infrastructure/Logging/CorrelationIdSubscriber.php`):
- `#[AsEventListener(event: KernelEvents::REQUEST, priority: 100)]` — generates UUID v4, sets on processor + request attributes
- `#[AsEventListener(event: KernelEvents::RESPONSE)]` — echoes `X-Correlation-Id` header from request attribute
- Both skip sub-requests via `$event->isMainRequest()`

**OpenRouterClient** (`backend/src/Shared/Infrastructure/Ai/OpenRouterClient.php`):
- Optional `?LoggerInterface $logger = null` (6th param after required config)
- Logs at each return path: success info, primary-429 warning (before fallback), all-models-429 error, transport error with retry count, retry-success notice vs first-try info
- Extracts `token_usage` from response body

**Three Messenger handlers** — consistent pattern in all:
- `$startTime = microtime(true)` at top
- `$status = 'noop_already_terminal'` (defensive default, always overwritten)
- try/catch/finally with status set per path
- finally block logs: `message_class`, `submission_id`, `duration_ms`, `status`
- Correlation ID set via `CorrelationIdProcessor::setCorrelationId(Uuid::v4()->toRfc4122())`

**Tests:**
- `CorrelationIdSubscriberTest` — 6 tests (UUID format, sub-request skip, header on response, header absent without correlation ID, header absent for empty ID, sub-response skip)
- 2 handler tests updated to pass `LoggerInterface` mock
- `OpenRouterClientTest` — `createClient()` passes `logger: null`

### Frontend — ESLint Cleanup (8 files modified)

Cleaned 12 ESLint errors:
- `AuthProvider.tsx` — Removed redundant client-side JWT expiry from `useEffect` (initializer handles it)
- `VerifyEmailPage.tsx` — Moved `!token` check to `useState` initializer
- `useAdminFailedMessages.ts` / `useGenerateSyntheticCase.ts` — `void` on floating promises, typed API response
- `FailedMessagesTable.tsx` — Removed unused `FailedMessageResource` import
- `ImpersonateButton.test.tsx` — `eslint-disable` for intentional empty promise executor
- `eslint.config.js` — Ignored `playwright.config.ts` and `src/e2e/**`

### New Type

```typescript
// frontend/src/api/types.ts
export interface SyntheticCaseResource {
  readonly id: string;
  readonly type: 'triage_submission';
  readonly attributes: {
    readonly isSynthetic: boolean;
    readonly status: string;
    readonly submittedAt: string;
  };
}
```

### Design Decisions

All documented in `raw_log.md` (entry for 2026-06-13). Key ones:
- UUID v4 for correlation IDs (not cleaner format)
- Static processor (not DI-scoped)
- Snake_case log field names
- Handler status: `noop_already_terminal`, `noop_not_awaiting_answer`, `noop_no_question`, `analysis_failed`, `success`, `failed_empty_answer`
- Monolog processor registered on all channels (no channel restriction)

### Bugs Found & Fixed

| Bug | Context | Fix |
|-----|---------|-----|
| `CorrelationIdProcessor` typed `array` but Monolog 3 passes `LogRecord` | 75 tests failed | Changed to `LogRecord $record`, `$record->extra['correlation_id']` |
| Named args can't skip optional param before required params | `OpenRouterClientTest` failed | Moved `$logger` after all required params in constructor |
| PHPStan 7 errors | Code review | Moved `$logger` param position |


### Code Review Fixes (5 Important + 1 Minor)

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | Missing terminal guard in ProcessSyntheticCaseMessageHandler | Important | Added `noop_already_terminal` guard |
| 2 | Missing warning on primary 429 before fallback | Important | Added `$this->logger?->warning(...)` |
| 3 | Missing notice on transport retry success | Important | Conditional: notice when `$attempts > 0` |
| 4 | `empty_answer` naming inconsistent | Important | Renamed → `failed_empty_answer` |
| 5 | `rate_limited_all_models` used warning not error | Important | Changed to `error` |
| 6 | `$status = 'noop'` unreachable | Minor | Changed to `'noop_already_terminal'` |

### Commits

**Backend** (on `master`, in nested `backend/` repo):
- `fea218d` — feat: add structured logging with correlation IDs

**Frontend** (on `master`, in nested `frontend/` repo):
- `3b0a0aa` — fix: resolve ESLint errors across auth, admin hooks, and tests

## Verification

| Check | Result |
|-------|--------|
| Backend PHPStan level 5 | ✅ Zero errors |
| Backend unit tests | ✅ 180/180 pass (531 assertions) |
| Backend integration tests | ⏭️ 45 skipped (no PostgreSQL in this environment) |
| Frontend TypeScript | ✅ Zero errors |
| Frontend ESLint | ✅ Zero errors |
| Frontend Vitest | ✅ 95/95 pass (13 files) |

## Not Implemented (Deferred)

- **Handler test logger assertions** — Minor, tests verify handler behavior not logging side-effects
- **`ProcessSyntheticTurnMessageHandlerTest`** — Most complex handler, zero existing coverage
- **Backend integration tests** — Require running PostgreSQL (Docker)

## Open Issues

| # | Title | Status |
|---|-------|--------|
| 11 | UX Polish: Loading states, error recovery, accessibility | `ready-for-human` |
| 12 | Rate Limiter for OpenRouter | `ready-for-agent` |
| 13 | Code Coverage: pcov + 80% + CI | `ready-for-agent` |
| 14 | E2E Test Suite: User Journey | `ready-for-agent` |
| 15 | E2E Test Suite: Admin Journey | `ready-for-agent` |

## Refs

- **Plan:** Issue #10 structured logging (design resolved via `grill-with-docs`)
- **Raw log:** `raw_log.md` (entry for 2026-06-13)
- **Issue #10:** https://github.com/psswid/triageflow-docs/issues/10
- **Handoff from prev session:** `docs/handoffs/handoff-2026-06-12-failed-messages.md`

## Context Files to Load

For a next sprint, the agent should load:
- `CONTEXT.md` — domain language and glossary
- `agents.md` — architecture decisions, project structure
- `docs/tools-scenarios-backend.md` — backend conventions (controller patterns, Messenger, testing)
- `docs/tools-scenarios-frontend.md` — frontend conventions (hooks, components, testing)
- `docs/handoffs/handoff-2026-06-13-structured-logging.md` — this session's context
- `raw_log.md` — full development log

## Suggested Skills

- `brainstorming` — for creative work like UX polish (Issue #11)
- `writing-plans` — create formal implementation plans for new issues
- `subagent-driven-development` — execute multi-task plans with quality gates
- `verification-before-completion` — verify tests pass before claiming completion
- `finishing-a-development-branch` — merge/pr/cleanup workflow
- `grill-with-docs` — stress-test new features against existing domain model
- `context7` — fetch up-to-date docs for Symfony or external libraries
- `find-skills` — discover additional skills for the task at hand
