# Handoff: Auth + Registration Security Complete — Admin Panel Next

## State

**Three concern areas just completed:**
1. **Auth session validation** — token no longer survives DB reset
2. **Registration security** — password confirmation + email verification
3. **Bugfixes** — messenger consumer, model fallback, submissions clickability

All three git repos are clean and pushed. User perspective is working end-to-end: register → verify email → login → submit triage → view results. Ready for admin panel improvements.

## What Was Done This Session

### Commits

| Repo | SHA | Summary |
|------|-----|---------|
| `triageflow-docs` | `64f9eba` | docs/setup updates for auth+email+model+infra |
| `triageflow-backend` | `881c2cd` | auth validation, registration security, model fix, mailer |
| `triageflow-frontend` | `7accb1e` | mount-time validation, password confirm, verify page, submissions |

### Auth Session (Issue 1)
- **Backend**: `GET /api/me` endpoint (`MeController.php`) returns authenticated user data via `#[CurrentUser]`. 3 tests (200 with JWT, 401 without, 401 with invalid).
- **Frontend**: `AuthProvider` mounts → client-side JWT exp check → `GET /api/me` → validates token server-side. `ProtectedRoute` shows `<Loader />` while validation is pending. On failure: clears all storage, unauthenticated, redirects `/login`.

### Registration Security (Issue 2)
- **Password confirmation**: Backend `Assert\Collection` for `password_confirmation` + manual match check (422 `PASSWORD_MISMATCH`). Frontend "Confirm Password" input with client-side validation.
- **Email verification**: User entity gains `emailVerifiedAt`, `emailVerificationToken` (64-char hex, constructor-generated), `verificationTokenExpiresAt` (+24h). Migration `Version20260610000001.php`.
- **`VerifyEmailController`** at `GET /api/verify-email` (PUBLIC_ACCESS). Handles: missing (400), invalid (404), expired (410), already (200), success (200).
- **`EmailVerifiedUserChecker`** implements `UserCheckerInterface` — blocks login if email unverified (skips ROLE_ADMIN).
- **Mailpit docker service** (SMTP:1025, Web:8025). `symfony/mailer` 7.4.12 installed.
- **Registration sends email** via `MailerInterface` (non-fatal try/catch).
- **Frontend**: `VerifyEmailPage.tsx` at `/verify-email?token=xxx`. Login page shows Mailpit link after registration, amber warning for unverified login error.
- **`DEFAULT_URI`** set to `http://localhost:5173` (was `http://localhost`).
- **`MESSENGER_TRANSPORT_DSN`** `auto_setup=1` (was `0` — prevents missing table on DB reset).

### Bugfixes
- **OpenRouter fallback**: Default model `openrouter/free` (was dead `google/gemma-4-31b-it:free`). `chat()` now switches to `openai/gpt-oss-120b:free` fallback on 429. Network retries use exponential backoff (2s, 4s, 8s).
- **Messenger consumer**: Added to `bin/setup.sh` — `messenger:consume async --time-limit=3600`. Processed backlogged triage submissions.
- **SubmissionsList**: Shows "View Details" link for non-failed statuses (was only "View Result" for completed). Routes to existing `/triage/:id/result` which already handles all statuses gracefully.
- **setup.sh fixes**: Mailpit uses 15-retry loop instead of `sleep 3`, messenger consumer uses if/then/else (was unconditional `success`).

## Current Architecture Summary

### Repos (3 separate, per ADR 0003)
- **docs** (this repo): `psswid/triageflow-docs` — README, ADRs, handoffs, plans, setup scripts
- **backend**: `psswid/triageflow-backend` — Symfony 7.4 (DDD-lite, custom controllers, no API Platform)
- **frontend**: `psswid/triageflow-frontend` — React 19, React Router v7, TanStack Query, Axios, Tailwind v4

### Backend endpoints
| Method | Path | Auth |
|--------|------|------|
| GET | `/health` | None |
| POST | `/api/register` | PUBLIC_ACCESS |
| POST | `/api/login` | PUBLIC_ACCESS |
| GET | `/api/me` | IS_AUTHENTICATED_FULLY |
| GET | `/api/verify-email?token=` | PUBLIC_ACCESS |
| POST | `/api/triage/submit` | ROLE_USER |
| POST | `/api/triage/{id}/answer` | ROLE_USER |
| GET | `/api/triage/status/{id}` | ROLE_USER |
| GET | `/api/triage/result/{id}` | ROLE_USER |
| GET | `/api/triage/submissions` | ROLE_USER |
| GET | `/api/admin/stats` | ROLE_ADMIN |
| GET | `/api/admin/submissions` | ROLE_ADMIN |
| GET | `/api/admin/submissions/{id}` | ROLE_ADMIN |
| GET | `/api/admin/users` | ROLE_ADMIN |
| POST | `/api/admin/users/{id}/impersonate` | ROLE_ADMIN |
| POST | `/api/admin/synthetic/generate` | ROLE_ADMIN |

### Frontend routes
| Path | Component | Guard |
|------|-----------|-------|
| `/` | → redirect `/triage` | — |
| `/verify-email` | `VerifyEmailPage` | Public |
| `/login` | `LoginPage` | Public (lazy) |
| `/register` | `RegisterPage` | Public (lazy) |
| `/triage` | `TriagePage` | Protected |
| `/triage/:id/result` | `TriageResultPage` | Protected |
| `/submissions` | `MySubmissionsPage` | Protected |
| `/admin` | `DashboardPage` | Admin (lazy) |
| `/admin/submissions/:id` | `SubmissionDetailPage` | Admin (lazy) |
| `/admin/users` | `UsersPage` | Admin (lazy) |

### Key domain terminology (from CONTEXT.md)
- **Triage Submission** — complete symptom report (not "case" or "intake")
- **User** — person who self-reports symptoms (not "patient")
- **Admin** — dashboard monitor (not "reviewer")
- **Initial Symptom Description** — free-text complaint start (not "chief complaint")
- **Turn** — one exchange in the AI interview (max 3, can finish earlier)
- **TriageOutcome** — embedded value object (specialist, urgency, justification) — null while interview in progress
- **Synthetic Case** — TriageSubmission with `isSynthetic=true`
- **Conversation History** — JSON column in TriageSubmission entity

### AI integration
- OpenRouter via custom HTTP client (`OpenRouterClient`). Model: `openrouter/free` → fallback `openai/gpt-oss-120b:free`. 3 retries with exponential backoff. 429 triggers fallback switch.

### Async processing
- Symfony Messenger with Doctrine transport. Consumer runs with `--time-limit=3600`. Synthetic turns have 10s delay for human-like timing.

### Test counts
- **Backend**: 223 tests, 753 assertions (PHPUnit)
- **Frontend**: 81 tests (Vitest)

## What Exists for Admin (next focus area)

- **DashboardPage** — stats + tabs (Overview/Submissions/Users) at `/admin`
- **SubmissionsTable** — lists all submissions
- **SubmissionDetailPage** — `/admin/submissions/:id` with full detail + history
- **UsersTable** — user list (filters system user) + ImpersonateButton
- **StatsGrid** — key metrics display
- **ImpersonationBanner** — amber banner when impersonating
- **SyntheticCase** generate button on dashboard
- **AdminController** — stats/submissions/users endpoints
- **SyntheticCaseController** — `POST /api/admin/synthetic/generate`

### Potential admin panel improvements
- Filtering/search/pagination on submissions/users tables
- Delete users or submissions
- Synthetic case generation scheduling configuration
- Activity logs or audit trail
- Responsive/layout polish
- Real-time updates via polling or SSE
- Error state handling on dashboard
- Bulk actions

## Existing Artifacts (do not duplicate)
- Implementation plan: `docs/superpowers/plans/2026-06-10-auth-session-email-verification.md`
- All ADRs: `docs/adr/` (0001-0006)
- Earlier handoffs: `docs/handoffs/handoff-2026-06-09-admin-impersonation.md`, `docs/handoffs/handoff-2026-06-09-synthetic-case-generator.md`
- Testing scenarios: `docs/testing/`
- Operating guide: `docs/operating-guide.md`
- Context/terminology: `CONTEXT.md`
- ADR 0006: System user at UUID `00000000-0000-0000-0000-000000000001` with `ROLE_SYSTEM`

## Infrastructure Notes
- **Docker services**: php (8.4-fpm), nginx, db (postgres:16), mailpit
- **Frontend dev**: `npm run dev` from `frontend/` (Vite on :5173)
- **Backend**: `docker compose up -d` from `backend/` (nginx on :8000)
- **Consumer**: `messenger:consume async --time-limit=3600` (started by setup.sh)
- **Mailpit**: `http://localhost:8025` for captured emails
- **Setup**: `bash bin/setup.sh` — one-command setup (clones subrepos, builds images, runs migrations, generates JWT keys, starts consumer)

## Sensitive Info (redacted from this doc)
- OpenRouter API key: set via `OPENROUTER_API_KEY` env var in `.env.local`
- JWT passphrase: set via `JWT_PASSPHRASE` env var in `.env.local`
- No default secrets in `.env.example` (placeholder values)

## Suggested Skills for Next Session
- **brainstorming** — before any new feature work or creative decisions on admin panel
- **grill-with-docs** — when designing anything that touches domain language
- **context7** — if exploring new libraries for admin panel features (e.g., data tables, charts)
- **ui-ux-pro-max** — for admin panel UI/layout improvements
- **verification-before-completion** — before claiming any work is done
- **requesting-code-review** — before merging to PR
- **finishing-a-development-branch** — when ready to integrate/merge
- **systematic-debugging** — if encountering issues with admin endpoints
