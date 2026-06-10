# Handoff: Admin Impersonation UI (Issue #6)

## State

**Issue #6 — Admin Tools: User Management + Impersonation UI** is fully implemented and verified.

## What Was Done

### Implementation (7 workstreams)

| # | Change | File |
|---|--------|------|
| 1 | Backend: Block system user (403 if `ROLE_SYSTEM`) | `backend/src/Admin/Infrastructure/Controller/ImpersonationController.php` |
| 2 | Frontend: AuthProvider impersonation state + sessionStorage | `frontend/src/components/auth/AuthProvider.tsx` |
| 3 | Frontend: ImpersonateButton (TanStack mutation, loading state) | `frontend/src/features/admin/components/ImpersonateButton.tsx` (NEW) |
| 4 | Frontend: UsersTable (queries users, filters system user) | `frontend/src/features/admin/components/UsersTable.tsx` (NEW) |
| 5 | Frontend: DashboardPage Users tab (replaced placeholder) | `frontend/src/features/admin/pages/DashboardPage.tsx` |
| 6 | Frontend: ImpersonationBanner (amber banner, all pages) | `frontend/src/components/layout/ImpersonationBanner.tsx` (NEW) |
| 7 | Frontend: AppLayout banner mount | `frontend/src/components/layout/AppLayout.tsx` |

### Housekeeping (this session)
- Added `.playwright-mcp/` to root `.gitignore`
- Removed hardcoded Chromium path from `.opencode/opencode.json` (now portable)

## Verification
- TypeScript `tsc --noEmit`: clean
- ESLint: clean (2 pre-existing e2e config errors)
- Vitest: 58/60 pass (2 pre-existing useTriageInterview polling timing failures)
- Vite build: clean, DashboardPage bundle 9.74kB
- PHP lint: no syntax errors

## Key Design Decisions
- **sessionStorage + React Context** for impersonation state (survives refresh without leaking admin's original JWT to disk)
- **System user blocked frontend AND backend** (filtered from table, 403 on controller)
- **isAdmin and isImpersonating are independent** — admin retains their role while viewing as another user
- **Banner in AppLayout** (outside `<Outlet />`) — visible on all routes, persists across navigation
- ADR 0006 defines system user at UUID `00000000-0000-0000-0000-000000000001` with `ROLE_SYSTEM`

## Existing Artifacts (do not duplicate)
- Issue on tracker: `#6` (Admin Tools — User Management + Impersonation UI)
- Backend commit: `55b337f` (ImpersonationController initial)
- ADR 0006: `docs/adr/0006-system-user.md`
- Earlier handoffs: `docs/handoffs/handoff-issue5-synthetic-case-generator.md`, `docs/handoffs/triageflow-handoff-2026-06-09.md`

## Suggested Skills for Next Session
- **brainstorming** — before any new feature work or creative decisions
- **grill-with-docs** — when designing anything that touches domain language
- **verification-before-completion** — before claiming any work is done
- **requesting-code-review** — before merging to PR
- **finishing-a-development-branch** — when ready to integrate/merge
