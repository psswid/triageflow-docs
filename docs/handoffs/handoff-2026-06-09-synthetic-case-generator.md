# Handoff — Issue #5: Synthetic Case Generator

> **State as of:** Tue, 09 Jun 2026 14:00+00:00
> **Session focus:** Full implementation + merge + live E2E verification
> **Backend HEAD:** `master` at `af653b8` (clean)

---

## What Was Built

Issue #5 — Admin synthetic case generation with AI-driven interview pipeline, impersonation support, and cron-scheduled generation.

**Pipeline (verified working via live E2E):**
```
Cron (0 * * * *) → GenerateSyntheticCaseTask
                  → GenerateSyntheticCaseHandler (resolves system user, generates symptom via OpenRouter)
                  → TriageSubmission::create(isSynthetic: true) + submit
                  → TriageAnalyzer::analyzeInitial() (AI analysis)
                    → if outcome: completeWithOutcome()
                    → if question: ProcessSyntheticTurnMessage + DelayStamp(10000ms)
                                    → ProcessSyntheticTurnMessageHandler (generates patient answer, runs follow-up analysis)
```

## Repositories

### Root repo (triageflow — docs)
- **Branch:** `master` (`03255c7`)
- **Uncommitted:** `raw_log.md` (modified), several untracked handoff/plan docs, `.opencode/opencode.json`
- No code files — docs-only repo

### Backend repo (`backend/` — triageflow-backend)
- **Branch:** `master` (`af653b8`)
- **Clean** — no uncommitted changes, feature branch deleted post-merge
- **System user:** `00000000-0000-0000-0000-000000000001` / `system@triageflow.local` / `["ROLE_SYSTEM"]` (exists in DB)

## Key Files Created/Modified

| File | Purpose |
|------|---------|
| `backend/migrations/Version20260609000001.php` | System user seed (empty password, ROLE_SYSTEM, sentinel timestamp) |
| `src/Synthetic/Application/Service/SyntheticSystemPrompt.php` | Prompt templates for symptom generation + patient answers |
| `src/Synthetic/Application/Command/GenerateSyntheticCaseHandler.php` | Orchestrator: system user → symptom → submission → initial analysis |
| `src/Synthetic/Application/Message/ProcessSyntheticTurnMessage.php` | DTO for follow-up turn processing |
| `src/Synthetic/Application/Message/ProcessSyntheticTurnMessageHandler.php` | Patient simulator + follow-up analysis loop |
| `src/Synthetic/Infrastructure/Scheduler/GenerateSyntheticCaseTask.php` | `#[AsCronTask('0 * * * *')]` — every hour on the hour |
| `src/Synthetic/Infrastructure/Controller/SyntheticCaseController.php` | `POST /api/admin/synthetic/generate` |
| `src/Synthetic/Infrastructure/Controller/ImpersonationController.php` | `POST /api/admin/users/{id}/impersonate` — returns JWT |
| `config/packages/scheduler.yaml` | Scheduler transport config |
| `config/packages/messenger.yaml` | Added `scheduler_default` transport + ProcessSyntheticTurnMessage routing |
| `tests/Synthetic/Infrastructure/TestOpenRouterClient.php` | Test double for OpenRouterClientInterface |
| `config/services_test.yaml` | Wired TestOpenRouterClient + TestTriageAnalyzer in test env |

## Deferred Follow-ups (from Code Review)

| Item | Detail |
|------|--------|
| I3 🟠 | No unit tests for Synthetic handler logic (edge cases: empty symptom retry, failed analysis → markFailed, no-op on terminal states) |
| I5 🟠 | No 403 test asserting non-admin gets forbidden on admin endpoints |
| m1 🟡 | Handler returns TriageSubmission entity — consider returning Uuid DTO |
| m3 🟡 | No guard against impersonating system user UUID |
| m6 🟡 | Retry count (1) differs from project standard (3) — intentional for symptom gen |

## Observability

- **Scheduler:** Next run at `Tue, 09 Jun 2026 14:00:00 +0000` (`0 * * * *`)
- **Messenger routing:** `ProcessSyntheticTurnMessage → async` (3 retries, 2s/4s/8s delay)
- **Failure transport:** `doctrine://default?queue_name=failed`
- **OpenRouter models:** `google/gemma-4-31b-it:free` (default), `openai/gpt-oss-120b:free` (fallback)
- **API consistency:** 184 total submissions in DB, 1 synthetic (from E2E test)

## Suggested Skills for Next Agent

- `context7` — if working with OpenRouter API, Messenger, or Symfony Scheduler docs
- `grill-with-docs` — before starting Issue #6 (frontend) or Issue #7 (triage enhancements)
- `writing-plans` — if the next feature needs a multi-task plan
- `dispatching-parallel-agents` — if Issue #6 frontend and work on deferred items can proceed independently
