# Combined Handoff: Issue #5 — Synthetic Case Generator

**Date:** 2026-06-09
**Sources merged:** `handoff-issue5-synthetic-case-generator.md` + `triageflow-handoff-2026-06-09.md`

---

## Session State

Issue #4 (Admin Dashboard) is **complete and merged via PR**. E2E verification ran **33/36 steps passing (91.7%)**, 8 bugs fixed inline. App is stable and clickable. Two 501 stubs remain — this issue finishes them.

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

## Codebase State (Post-E2E Fixes)

### What's working ✅

- **Auth flow** (React Context): Register, Login, JWT persistence, Logout (SPA-style), ProtectedRoute/AdminRoute guards
- **Triage interview**: Submit symptom → AI via Messenger → 3 turns → auto-navigate to result
- **Result page**: Specialist, urgency badge, justification, conversation history
- **My Submissions**: `/submissions` table with status/specialist/urgency/turns/date, "View Result" links
- **Admin Dashboard**: `/admin` with Overview (stats, breakdowns) + Submissions tab (full table) + detail page
- **Edge cases**: Custom 404, "Access Denied" page, error boundary

### Messenger (Critical Fix Applied)

- `symfony/doctrine-messenger` was **missing** — triage messages were never consumed
- Installed, table created, consumer started with `--time-limit=600`
- **CHECK BEFORE STARTING:** Consumer may have expired:
  ```bash
  docker exec triageflow_php php bin/console messenger:consume async --time-limit=600 -vv
  ```
- ⚠️ Plan: Messenger consumer should be a Docker Compose service, not manual start

### Bugs Fixed (8 total, see `raw_log.md`)

- 🔴 3 critical: Messenger not running, JSON:API unwrap in useTriagePolling, AI markdown wrapper
- 🟡 3 high: Auth Context refactor, TriageController type import, MySubmissionsPage placeholder
- 🟢 2 low: Route errorElement, custom 404 page

### Key Files Changed During E2E Fixes

**Auth Context (React):**
- `frontend/src/features/auth/components/auth/AuthProvider.tsx` — new
- `frontend/src/features/auth/hooks/useAuth.ts` — refactored to useContext
- `frontend/src/App.tsx` — AuthProvider wraps RouterProvider

**Submissions:**
- `frontend/src/features/submissions/hooks/useMySubmissions.ts` — new
- `frontend/src/features/submissions/components/SubmissionsList.tsx` — new
- `frontend/src/features/submissions/pages/MySubmissionsPage.tsx` — implemented

**Error Handling:**
- `frontend/src/components/shared/RouteErrorFallback.tsx` — new
- `frontend/src/components/shared/NotFoundPage.tsx` — new
- `frontend/src/routes.tsx` — errorElement + path:* catch-all added

**Backend Fixes:**
- `backend/src/Triage/Infrastructure/Controller/TriageController.php` — added `use` statement
- `backend/src/Triage/Infrastructure/AI/TriageAnalyzer.php` — markdown strip regex

### What's already in place for Issue #5

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

### Unimplemented Features (not blockers)

- Synthetic case generation (this issue)
- Admin Users page (placeholder text only)
- User impersonation (this issue)

## Critical Deltas: Plan vs Reality

| Aspect | Plan says | Actual codebase | Action |
|--------|-----------|----------------|--------|
| AI interface | `Symfony\AI\Platform\PlatformInterface` | `App\Shared\Infrastructure\Ai\OpenRouterClientInterface` | Use actual interface |
| SubmitTriageCommand signature | Takes `userId: Uuid`, `initialDescription`, `isSynthetic` | Takes `initialDescription: string`, `user: User` (no isSynthetic field) | Look up User entity by UUID, set isSynthetic via `TriageSubmission::create()` |
| isSynthetic on submission | Passed as constructor arg | `TriageSubmission::submit()` doesn't set it; `TriageSubmission::create(User $user, bool $isSynthetic)` is correct factory | Use `::create()` not `::submit()` in handler |
| Messenger routing | `SubmitTriageCommand` needs routing | Handled synchronously (no `__invoke` handler registered in messenger) | Check handler registration |
| Cooldown mechanism | 10s between turns for synthetic cases | No cooldown logic exists | Implement delay (delayed messenger message or handler sleep) |

## Files to Create

```
backend/src/Synthetic/Application/GenerateSyntheticCaseHandler.php
backend/src/Synthetic/Infrastructure/Scheduler/GenerateSyntheticCaseTask.php
backend/src/Admin/Infrastructure/Controller/SyntheticCaseController.php
backend/src/Admin/Infrastructure/Controller/ImpersonationController.php
backend/config/packages/scheduler.yaml
# Migration: system user insert + verification
```

## Key Design Decisions

1. **System user**: UUID `00000000-0000-0000-0000-000000000001`. Create via migration. Must exist before scheduler runs.
2. **Synthetic AI prompt**: Generate realistic first-person symptom descriptions. Temperature ~0.7. Rotate across medical domains (cardiology, neurology, dermatology, orthopedics, gastroenterology, respirology).
3. **Cooldown**: 10s delay between turns simulates human typing. Delayed messenger message or handler sleep.
4. **Manual trigger**: Extract from AdminController 501 stub → `SyntheticCaseController` (`POST /api/admin/synthetic/generate`).
5. **Impersonation**: Extract from AdminController 501 stub → `ImpersonationController`. Uses Lexik JWT to generate token for target user.
6. **isSynthetic flag**: Modify `SubmitTriageHandler` to accept optional flag, or call `TriageSubmission::create()` directly.

## Context Files (for agent loading)

**Load via `Read` before starting:**
- `backend/agents.md` — Admin/submission patterns, repository conventions, OpenRouter integration rules
- `docs/adr/0002-custom-ai-no-bundle.md` — Why custom OpenRouterClient is used
- `docs/adr/0004-single-aggregate-embedded-outcome.md` — TriageOutcome embedded in submission
- `.opencode/skills/triageflow/SKILL.md` — Domain conventions, specialist/urgency enum values, status machine

**Fetch via ExternalScout + Context7:**
- `context7 symfony scheduler` — CronTrigger, scheduler configuration
- `context7 symfony messenger` — Message routing, delayed messages (for cooldown)

## Test Credentials

- Regular user: `e2e-ui-test-1780993890@test.com` / `<redacted>`
- Admin user: `admin-e2e-1780993821@test.com` / `<redacted>`

## Suggested Skills

| Skill | When |
|-------|------|
| **writing-plans** | Break down Issue #5 into subtasks before coding |
| **executing-plans** | Structured execution with checkpoints + worktree isolation |
| **dispatching-parallel-agents** | Backend synthetic gen + frontend UI are independent |
| **docker-patterns** | Messenger consumer should be Docker Compose service |
| **verification-before-completion** | Verify: scheduler runs, AI generates varied symptoms, cases appear in dashboard |
| **requesting-code-review** | Before merging any branch |
| **receiving-code-review** | If encountering Issue #4 ADR-0004 feedback (embedded fields still queryable) |
| **git-workflow** | Branch naming and commit conventions |
| **context7** | Current Symfony Scheduler/Messenger docs |

## References

- **Backend plan:** `docs/superpowers/plans/2026-05-28-backend-foundation.md` lines 2702-2881 (Tasks 16-17)
- **Issue #5 on GitHub:** https://github.com/psswid/triageflow-docs/issues/5
- **Backend repo:** https://github.com/psswid/triageflow-backend
- **Frontend repo:** https://github.com/psswid/triageflow-frontend
- **Docs repo:** https://github.com/psswid/triageflow-docs
- **Bug log:** `raw_log.md` → `## 2026-06-09 — E2E Verification + Bugfixing Session`

## Code Review Findings (from Issue #4)

- 🔴 `.playwright-mcp/` → add to `.gitignore`
- 🟡 `opencode.json` → hardcoded Chromium path
- 🟡 ADR-0004 nuance → embedded outcome columns are still queryable at DB level

## Follow-up Items from Issue #4

- Migrate `POST /api/admin/synthetic/generate` from AdminController 501 stub → `SyntheticCaseController`
- Migrate `POST /api/admin/users/{id}/impersonate` from AdminController 501 stub → `ImpersonationController`
- Messenger consumer should run as Docker Compose service (not manual `messenger:consume`)

## Known Gaps (future)

- E2E Playwright suite conflicts with vitest (separate runner needed)
- Backend DB functional tests blocked by missing `pdo_pgsql`
- Expired JWT handling untested
- `.playwright-mcp/` transient artifacts should be gitignored
