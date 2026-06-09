# Handoff: Issue #5 — Synthetic Case Generator

**Date:** 2026-06-09
**From:** Issue #4 (Admin Dashboard) — complete
**Target:** Issue #5 (Synthetic Case Generator)

---

## Session State

Issue #4 (Admin Dashboard) is **complete and merged via PR**. All admin endpoints return real data except two 501 stubs that this issue finishes. The monorepo `docs/` repo has the issue chain; backend and frontend each have their own repos with PRs already created.

## What Issue #5 Is

**Title:** Synthetic Case Generator: Scheduler + manual trigger
**GitHub:** https://github.com/psswid/triageflow-docs/issues/5
**Status:** `ready-for-agent`, unassigned
**Repos to work in:** `psswid/triageflow-backend` (+ `psswid/triageflow-docs` for updates)

Automated synthetic case generation for the demo — the scheduler calls OpenRouter AI every 60s to generate realistic symptom descriptions and pushes them through the triage pipeline with `isSynthetic=true`.

## Acceptance Criteria

- [ ] Scheduler generates one synthetic case every 60 seconds
- [ ] AI generates varied, realistic symptom descriptions (cardio, neuro, derm, etc.)
- [ ] Synthetic cases flow through the same triage pipeline as user submissions
- [ ] 10s cooldown between turns for synthetic cases (simulate typing)
- [ ] All synthetic submissions have `isSynthetic=true`
- [ ] `POST /api/admin/synthetic/generate` (Admin only) triggers immediate generation
- [ ] System user (`00000000-0000-0000-0000-000000000001`) owns all synthetic submissions
- [ ] Admin dashboard live feed shows synthetic cases appearing in real-time (already built)

## Codebase State (Post-Issue #4)

### What's already in place

**Backend (`psswid/triageflow-backend`, branch `feature/admin-dashboard`):**
- `AdminController` has `POST /api/admin/synthetic/generate` as a **501 stub**
- `AdminController` has `POST /api/admin/users/{id}/impersonate` as a **501 stub**
- `SubmitTriageCommand` exists (takes `string $initialDescription` + `User $user`)
- `SubmitTriageHandler` — handles the command, validates, creates submission, starts AI interview
- `TriageSubmission::create(User $user, bool $isSynthetic = false)` — the `isSynthetic` factory variant exists but is NOT called by `SubmitTriageHandler` (which uses `TriageSubmission::submit()`)
- `OpenRouterClientInterface` + `OpenRouterClient` — in `src/Shared/Infrastructure/Ai/`
- `TriageAnalyzer` — orchestrates AI calls (initial + follow-up)
- `UserRepository::findAll()` — works
- `TriageSystemPrompt` — exists for the triage interview prompt
- `config/routes/admin.yaml` — routes already configured
- Scheduler package: check `composer.json` for `symfony/scheduler` dependency

**Frontend (`psswid/triageflow-frontend`, branch `feature/admin-dashboard`):**
- `DashboardPage` already has a "Generate Synthetic Case" button wired to `ENDPOINTS.SYNTHETIC_GENERATE`
- StatsGrid already shows synthetic count
- SubmissionsTable already shows `isSynthetic` badge
- All hooks work with auto-refetch — new synthetic cases appear automatically

### What doesn't exist yet

- `backend/src/Synthetic/` directory — completely empty
- `GenerateSyntheticCaseHandler` — does not exist
- `GenerateSyntheticCaseTask` — does not exist
- `config/packages/scheduler.yaml` — does not exist
- System user migration — does not exist
- `SyntheticCaseController` — does not exist (logic is in AdminController 501 stub)
- `ImpersonationController` — does not exist (logic is in AdminController 501 stub)
- Synthetic AI prompt — does not exist (different from `TriageSystemPrompt`)

## Critical Deltas: Plan vs Reality

The implementation plan in `docs/superpowers/plans/2026-05-28-backend-foundation.md` (Tasks 16-17) contains code samples that **differ from the actual codebase**:

| Aspect | Plan says | Actual codebase | Action |
|--------|-----------|----------------|--------|
| AI interface | `Symfony\AI\Platform\PlatformInterface` | `App\Shared\Infrastructure\Ai\OpenRouterClientInterface` | Use actual interface instead |
| SubmitTriageCommand signature | Takes `userId: Uuid`, `initialDescription`, `isSynthetic` | Takes `initialDescription: string`, `user: User` (no isSynthetic field) | Look up the `User` entity by UUID, set isSynthetic via `TriageSubmission::create()` or on the resulting submission |
| isSynthetic on submission | Passed as constructor arg | `TriageSubmission::submit()` doesn't set it; `TriageSubmission::create(User $user, bool $isSynthetic)` is the correct factory | Use `::create()` not `::submit()` when calling from handler |
| Messenger routing | `SubmitTriageCommand` needs routing | `SubmitTriageCommand` is handled synchronously (no `__invoke` handler registered in messenger) | Check if `SubmitTriageHandler` is registered as a messenger handler or called directly |
| cooldown mechanism | 10s between turns for synthetic cases | No cooldown logic exists anywhere | Need to implement delay in the synthetic case flow (perhaps scheduler-level or in the AI interaction loop) |

## Files to Create

From `docs/superpowers/plans/2026-05-28-backend-foundation.md` Task 16-17:

```
backend/src/Synthetic/Application/GenerateSyntheticCaseHandler.php
backend/src/Synthetic/Infrastructure/Scheduler/GenerateSyntheticCaseTask.php
backend/src/Admin/Infrastructure/Controller/SyntheticCaseController.php
backend/src/Admin/Infrastructure/Controller/ImpersonationController.php
backend/config/packages/scheduler.yaml
# Migration: system user insert + verification
```

## Key Design Decisions

1. **System user**: Needs UUID `00000000-0000-0000-0000-000000000001`. Create via migration. The user must exist before the scheduler runs.
2. **Synthetic AI prompt**: Must instruct AI to generate realistic first-person symptom descriptions. Keep temperature at ~0.7 for variety. Should rotate across medical domains (cardiology, neurology, dermatology, orthopedics, gastroenterology, respirology, etc.)
3. **Cooldown**: The 10s delay between turns for synthetic submissions simulates human typing. Could be implemented via delayed messenger message or sleeping in the handler.
4. **Manual trigger**: Extract from AdminController 501 stub into dedicated `SyntheticCaseController` with `POST /api/admin/synthetic/generate`.
5. **Impersonation**: Extract from AdminController 501 stub into `ImpersonationController`. Uses Lexik JWT to generate a token for the target user's ID.
6. **isSynthetic flag**: `SubmitTriageHandler` currently uses `TriageSubmission::submit()` which doesn't set `isSynthetic`. When dispatching from the synthetic handler, you either need to modify `SubmitTriageHandler` to accept an optional flag, or call `TriageSubmission::create()` directly and then dispatch a different message.

## Context Files (for agent loading)

**Before starting**, load these context files via `Read`:
- `backend/agents.md` — Admin/submission patterns, repository conventions, OpenRouter integration rules
- `docs/adr/0002-custom-ai-no-bundle.md` — Why custom OpenRouterClient is used (not symfony/ai-bundle)
- `docs/adr/0004-single-aggregate-embedded-outcome.md` — TriageOutcome embedded in submission
- `.opencode/skills/triageflow/SKILL.md` — Domain conventions, specialist/urgency enum values, status machine

**External docs to fetch** (use ExternalScout + Context7):
- `context7 symfony scheduler` — CronTrigger, scheduler configuration
- `context7 symfony messenger` — Message routing, delayed messages (for cooldown)

## Suggested Skills

- **writing-plans** — If you need to break down Issue #5 into subtasks before coding
- **executing-plans** — If you create a plan file and want structured execution with checkpoints
- **dispatching-parallel-agents** — Multiple Synthetic directory files can be created in parallel
- **verification-before-completion** — Before claiming completion, verify: scheduler runs, AI generates varied symptoms, cases appear in admin dashboard
- **receiving-code-review** — If you encounter the code review from Issue #4 about ADR-0004 nuance (embedded fields still queryable)
- **git-workflow** — For branch naming and commit conventions
- **context7** — For current Symfony Scheduler/Messenger docs
- **customize-opencode** — Only if modifying `.opencode/opencode.json` (hardcoded Chromium path noted in code review)

## References

- **Backend plan:** `docs/superpowers/plans/2026-05-28-backend-foundation.md` lines 2702-2881 (Tasks 16-17)
- **Issue #5 on GitHub:** https://github.com/psswid/triageflow-docs/issues/5
- **Backend repo:** https://github.com/psswid/triageflow-backend
- **Frontend repo:** https://github.com/psswid/triageflow-frontend
- **Docs repo (issue tracker):** https://github.com/psswid/triageflow-docs
- **Code review findings** (from Issue #4 handoff area):
  - 🔴 `.playwright-mcp/` → add to `.gitignore`
  - 🟡 `opencode.json` → hardcoded Chromium path
  - 🟡 ADR-0004 nuance → embedded outcome columns are still queryable at DB level

## Follow-up Items from Issue #4

- Migrate `POST /api/admin/synthetic/generate` from AdminController 501 stub → `SyntheticCaseController`
- Migrate `POST /api/admin/users/{id}/impersonate` from AdminController 501 stub → `ImpersonationController`
- Both endpoints exist and are wired but return "Not yet implemented"
