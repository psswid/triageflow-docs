# Handoff: Async Queue for Synthetic Cases + Generate Button

## State

**This session completed Story 9 from manual-test-stories.md:**

1. **Async queue for synthetic AI analysis** — `GenerateSyntheticCaseHandler` now creates the submission + dispatches `ProcessSyntheticCaseMessage` (returns 202) instead of running the full AI pipeline inline (was blocking ~4-10s).
2. **Worker container** — separate `worker` Docker service running `messenger:consume async --limit=10`.
3. **Frontend button** — "Generate Synthetic Case" button on admin dashboard with green success banner.
4. **Bugfixes** — AI symptom overflow truncation (500-char defense), import typo fix.

**Uncommitted changes in both backend and frontend repos.** All tests pass. Docker stack running with worker actively processing.

## What Was Done This Session

### Uncommitted Changes

**Backend** (`triageflow-backend`):

| File | Change |
|------|--------|
| `src/Synthetic/Application/Message/ProcessSyntheticCaseMessage.php` | NEW — message carrying `submissionId` |
| `src/Synthetic/Application/Message/ProcessSyntheticCaseMessageHandler.php` | NEW — `#[AsMessageHandler]`, loads submission, calls `TriageAnalyzer::analyzeInitial()`, handles result/question/failure |
| `src/Synthetic/Application/Command/GenerateSyntheticCaseHandler.php` | REFACTORED — removed inline AI analysis, dispatches `ProcessSyntheticCaseMessage` instead; added 500-char truncation |
| `config/packages/messenger.yaml` | MODIFIED — routes `ProcessSyntheticCaseMessage` to async transport |
| `docker-compose.yml` | MODIFIED — added `worker` service (builds from same Dockerfile, runs `messenger:consume async --limit=10`) |
| `compose.override.yaml` | NEW — mailpit service (from Symfony recipe) |
| `tests/Synthetic/Application/Command/GenerateSyntheticCaseHandlerTest.php` | UPDATED — 3 tests (pending submission + message dispatch, empty retry, no system user) |
| `tests/Synthetic/Application/Message/ProcessSyntheticCaseMessageHandlerTest.php` | NEW — 5 tests (result, question, failure, not found, missing description) |

**Frontend** (`triageflow-frontend`):

| File | Change |
|------|--------|
| `src/features/admin/hooks/useGenerateSyntheticCase.ts` | NEW — TanStack Query mutation hook, invalidates admin stats + submissions on success |
| `src/features/admin/pages/DashboardPage.tsx` | MODIFIED — "Generate Synthetic Case" button in header row, green success banner (4s auto-dismiss); fixed import typo |

### Design Decision: Async Queue for AI (Options A/B/C)

Three options discussed via grill-with-docs:
- **Option A (chosen)**: Queue the AI analysis, keep symptom generation sync. Submit case synchronously (creates DB row), then dispatch `ProcessSyntheticCaseMessage` for background analysis. Worker picks it up.
- **Option B**: Queue the entire pipeline including symptom generation.
- **Option C**: Keep everything inline (pre-existing behavior, 4-10s response time).

Rationale: A gives the best UX (fast 202 response) while keeping symptom generation synchronous so the submit response always includes a submission ID. B was rejected because the user would have to poll just to see if the submission entity existed.

### Bugfix: AI Symptom Overflow (500-char defense)

The AI symptom generation prompt says "Keep under 500 characters" but the model sometimes ignores this (generated 1776 chars in one call). Added truncation in `generateSymptom()` as defense-in-depth: `mb_substr($symptom, 0, 497) . '...'`.

### Bugfix: Import Typo

`DashboardPage.tsx` line 5 imported `useAdminSubscriptions` → should be `useAdminSubmissions`.

## Current Architecture

### Repos (3 separate per ADR 0003)
- **docs**: `psswid/triageflow-docs` — this repo, setup scripts, ADRs, handoffs
- **backend**: `psswid/triageflow-backend` — Symfony 7.4, DDD-lite
- **frontend**: `psswid/triageflow-frontend` — React 19, Vite, TanStack Query, Tailwind v4

### Docker services (all running)
| Container | Image | Purpose |
|-----------|-------|---------|
| `triageflow_php` | `backend-php` | php 8.4-fpm |
| `triageflow_nginx` | `nginx:alpine` | :8000 → php |
| `triageflow_db` | `postgres:16-alpine` | PostgreSQL |
| `triageflow_mailpit` | `axllent/mailpit` | SMTP/webmail |
| `triageflow_worker` | `backend-worker` | messenger consumer, --limit=10 |

### Async message topology
| Message | Handler | Transport | Notes |
|---------|---------|-----------|-------|
| `ProcessTriageMessage` | `ProcessTriageMessageHandler` | async | User triage follow-up analysis |
| `ProcessSyntheticCaseMessage` | `ProcessSyntheticCaseMessageHandler` | async | NEW — initial synthetic AI analysis |
| `ProcessSyntheticTurnMessage` | `ProcessSyntheticTurnMessageHandler` | async | 10s DelayStamp for human-like timing |

### Test counts
- **Backend**: 228 tests, 775 assertions
- **Frontend**: 81 tests (Vitest)

## Infrastructure Notes
- Docker stack is **currently running** — all 6 services up
- Worker actively consuming messages (verified via E2E)
- Must rebuild worker on code changes: `docker compose up -d --build worker`
- Worker exits after 10 messages (--limit=10); `restart: unless-stopped` restarts it
- Volume note: anonymous `/var/www/vendor` persists across rebuilds. Run `docker compose build --no-cache php` if vendor/ is stale
- Frontend dev server on `:5173`, nginx on `:8000`, DB on `:5432`, Mailpit on `:8025`

## Existing Artifacts (do not duplicate)
- All ADRs: `docs/adr/` (0001-0006)
- Earlier handoffs: `docs/handoffs/`
- Testing scenarios: `docs/testing/manual-test-stories.md`
- Operating guide: `docs/operating-guide.md`
- Context/terminology: `CONTEXT.md`
- Implementation plans: `docs/superpowers/plans/`
- Raw log: `raw_log.md` (2026-06-11 entry added)

## Sensitive Info (redacted from this doc)
- OpenRouter API key: set via `OPENROUTER_API_KEY` in `.env.local`
- JWT passphrase: set via `JWT_PASSPHRASE` in `.env.local`

## Suggested Skills for Next Session
- **brainstorming** — before any new feature work
- **grill-with-docs** — when designing anything that touches domain language
- **writing-plans** — for formal plan creation before implementation
- **task-management** — for tracking subtasks during implementation
- **verification-before-completion** — before claiming any work is done
- **systematic-debugging** — if encountering issues with the async queue or worker
- **requesting-code-review** — before merging
- **finishing-a-development-branch** — when ready to integrate/merge
