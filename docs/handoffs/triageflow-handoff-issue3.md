# Handoff — Issue #2 Complete → Issue #3 Ready

**Session date:** 2026-05-29  
**Session context:** `.tmp/sessions/2026-05-29-issue2-auth/context.md`  
**Status:** All 6 subtasks complete, verified, pushed to all 3 repos.

---

## What Was Done (Issue #2 — User Authentication)

Implemented JWT-based auth across Symfony backend and React frontend:

| Repo | Remote | Head | Commits |
|------|--------|------|---------|
| Backend | `psswid/triageflow-backend` | `bb8f4a3` | 4 (test infra → entity → auth → test fix) |
| Frontend | `psswid/triageflow-frontend` | `9c09721` | 2 (scaffold → pages) |
| Docs | `psswid/triageflow-docs` | `0e50adb` | 1 (raw_log update) |

### Backend (19 tests, 46 assertions)
- `User` entity: UUID PK, email (unique), roles (json), password (hashed), createdAt. `register()` named constructor, `promoteToAdmin()`.
- `POST /api/register` — Symfony Validator constraints, duplicate-email 422, password hashing, JSON:API 201
- `POST /api/login` — json_login firewall (already configured), returns JWT
- `JWTSubscriber` — enriches JWT payload with `roles` claim on `lexik_jwt_authentication.on_jwt_created`
- `services.yaml` — `UserRepository` → `DoctrineUserRepository` binding
- `config/routes/user.yaml` — attribute-based routing for User controllers

### Frontend (tsc + eslint clean)
- `useAuth` hook — JWT decode, login/logout, isAdmin from roles
- `ProtectedRoute` + `AdminRoute` — React Router `<Navigate>` guards
- `Header` — auth-aware nav (Login/Register vs authenticated links)
- `AppLayout` — Header + Outlet
- `LoginPage` — useMutation → POST /api/login → store JWT → redirect
- `RegisterPage` — useMutation → POST /api/register → validation errors → redirect
- `routes.tsx` — createBrowserRouter with all routes, lazy imports for admin
- 6 stub pages for future issues (TriagePage, TriageResultPage, MySubmissionsPage, DashboardPage, SubmissionDetailPage, UsersPage)

---

## Current State

### Backend (Docker at `localhost:8000`)
- 3 containers: `triageflow_php`, `triageflow_nginx`, `triageflow_db` (PostgreSQL 16)
- Dev DB `triageflow` + test DB `triageflow_test` — both have `users` table from migration
- `POST /api/register` + `POST /api/login` functional
- JWT keys at `config/jwt/private.pem` + `config/jwt/public.pem`
- DDD Light dirs exist: `src/{Triage,User,Admin,Shared}/`
- Only User bounded context has code; Triage/Admin are empty dirs

### Frontend (Vite at `localhost:5173`)
- `@tanstack/react-query` v5 + `react-router-dom` v7 configured
- API client with JWT interceptor (Bearer + 401→/login redirect)
- UI components: Button, Input, Card, Badge, Spinner, Loader, ErrorBoundary, EmptyState
- All pages are stubs except LoginPage + RegisterPage (fully implemented)

### Packages Installed During Issue #2
- `symfony/uid` — UUID generation (was missing from #1 scaffold)
- `symfony/validator` — controller validation (was missing)
- `symfony/browser-kit` — WebTestCase/KernelBrowser (was missing)
- `phpunit/phpunit` v11 — test framework (was in composer.json but not installed)

---

## Next: Issue #3 — Triage Pipeline

Issue chain: #1→#2→**#3**→{#4, #5}→#6→#7 on `psswid/triageflow-docs`

### Reference Documents
- **Backend plan**: `docs/superpowers/plans/2026-05-28-backend-foundation.md` — Tasks 6, 9, 10, 11 (TriageSubmission entity, AI Analyzer, Submit command/handler, TriageController)
- **Frontend plan**: `docs/superpowers/plans/2026-05-28-frontend-foundation.md` — Tasks 4, 5, 6 (Triage interview, result page, submission list)
- **Domain glossary**: `CONTEXT.md` — Triage Submission, Turn, Conversation History, Initial Symptom Description, Synthesis Case
- **ADR 0002**: `docs/adr/0002-custom-ai-no-bundle.md` — No `symfony/ai-bundle`, AI via HTTP Client directly
- **Coding standards**: `agents.md`, `backend/agents.md`

### What Issue #3 Needs

**Backend** (from plan Tasks 6, 9, 10, 11):
- TriageSubmission entity — UUID, User relation (ManyToOne), conversationHistory (json), status enum, specialist/urgency enums, isSynthetic, submittedAt/processedAt
- TriageSubmissionRepository interface + Doctrine implementation
- TriageSystemPrompt — medical triage prompt with specialist list + urgency + JSON output format
- TriageAnalyzer — calls OpenRouter API via `symfony/http-client` (NOT symfony/ai — doesn't exist)
- SubmitTriageCommand + SubmitTriageHandler — creates submission, dispatches async Message
- ProcessTriageMessage — Messenger message for async AI processing
- TriageController — POST /api/triage/submit, GET /api/triage/status/{id}, POST /api/triage/{id}/answer, GET /api/triage/result/{id}, GET /api/triage/submissions

**Frontend** (from plan Tasks 4, 5, 6):
- Replace TriagePage stub with symptom input form (textarea + submit)
- Triage interview flow (poll for AI follow-up questions, display conversation, collect answers)
- TriageResultPage — display specialist, urgency level (colored badge), justification, conversation history
- MySubmissionsPage — list user's submissions with status badges, link to results

### Bootstrapping Notes
- Backend Docker: `cd backend && docker compose up -d`
- Backend commands inside Docker: `docker compose run --rm php composer ...` / `docker compose run --rm php bin/console ...`
- Frontend: `cd frontend && npm run dev`
- Backend tests: `docker compose run --rm php vendor/bin/phpunit`
- Frontend checks: `npx tsc -b && npx eslint .`
- Git: commit backend and frontend separately (different repos)
- Test DB needs reset between runs: `docker compose run --rm php bin/console doctrine:database:drop --env=test --force --if-exists` then recreate+migrate
- OpenRouter API key is in `backend/.env` as `OPENROUTER_API_KEY`

### Known Gaps / Watch Out For
- **No DAMA bundle** — test DB is not transactionally isolated; use `uniqid()` for unique test data
- **No symfony/ai-bundle** — doesn't exist on Packagist; use `symfony/http-client` directly with OpenRouter API
- **UUID PK strategy** — use manual `Uuid::v4()` in constructor, not `doctrine.uuid_generator` (incompatible)
- **No triage routes exist yet** — the auth test's `testProtectedEndpointRequiresAuth` uses GET /api/login returning 405; update to test real triage endpoint once TriageController exists
- **Frontend stub pages need replacement** — TriagePage, TriageResultPage, MySubmissionsPage all render just a heading

### Dependency Graph for Issue #3

```
Task 6: TriageSubmission entity + repository + migration
  ↓
Task 9: TriageSystemPrompt + TriageAnalyzer service
  ↓
Task 10: SubmitTriageCommand + Handler + ProcessTriageMessage
  ↓
Task 11: TriageController (all 5 endpoints)
```

Frontend (independent of backend, can run in parallel):
```
Task 4: TriagePage (symptom input + interview flow)
Task 5: TriageResultPage
Task 6: MySubmissionsPage
```

---

## Suggested Skills

| Skill | When |
|-------|------|
| `tdd-workflow` | Before writing ANY code — mandatory |
| `brainstorming` | Before designing TriageSubmission entity or AI analyzer |
| `grill-with-docs` | Stress-test plan against domain model + CONTEXT.md terms |
| `context7` | Fetch current OpenRouter API docs for AI call patterns |
| `subagent-driven-development` | For parallel backend+frontend subtask execution |
| `verification-before-completion` | Before claiming any task complete |
| `handoff` | When ready to pass to Issue #4 |

---

## Session Artifacts

- Session context: `.tmp/sessions/2026-05-29-issue2-auth/context.md`
- Task breakdown: `.tmp/tasks/issue2-auth/` (task.json + 6 subtask JSONs)
- Raw log: `raw_log.md` (updated with Issue #2 entry)

*Safe to delete `.tmp/` directories when done.*
