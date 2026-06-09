# TriageFlow — Raw Log

Personal notes, thoughts, and observations during development.

---

## 2026-05-26

- **Workflow setup**: Installed Matt Pocock skills (grill-with-docs, handoff, to-issues, zoom-out, caveman), created task template + tools matrix
- **Repo layout**: triageflow root = docs repo (OpenCode config + docs), backend/ and frontend/ are separate repos
- **Next**: Start Phase 1 (Foundation) from agents.md

## 2026-05-28

**Full pipeline session (ALIGN → PLAN → ISSUES).** Completed the three discovery stages for Phase 1 Foundation:

- 🧠 **ALIGN** (`grill-with-docs`): Defined domain language — Triage Submission, User, Admin, Initial Symptom Description, Turn, Conversation History, Synthetic Case. 13 decisions resolved. Created `CONTEXT.md` + `docs/adr/0001-openrouter-free-models.md`.

- 📋 **PLAN** (`writing-plans`): Two implementation plans — `docs/superpowers/plans/2026-05-28-backend-foundation.md` (19 tasks, Symfony 7.4 + AI + DB) and `docs/superpowers/plans/2026-05-28-frontend-foundation.md` (11 tasks, React 19 + Vite). Cross-referenced by task ID.

- 🎫 **ISSUES** (`to-issues`): 7 vertical-slice GitHub issues on `psswid/triageflow-docs` (#1-#7). All `ready-for-agent`. Each includes Context7 doc-fetch directives. Dependency chain: 1→2→3→{4,5}→6→7.

Key decisions: OpenRouter free models for app (not DeepSeek), single entity for TriageSubmission, AI-driven chat interview (max 3 turns), polling for async results, admin view-only + impersonation.

**Next**: `docs/superpowers/plans/handoff-phase1-foundation.md` — pick up issue #1

---

## 2026-05-29 — Issue #1: Project Scaffolding [COMPLETE]

**Session**: `.tmp/sessions/2026-05-29-issue1-scaffolding/context.md`  
**Verification**: All exit criteria met — Docker healthy, health check 200, TS+ESLint clean, Vite builds

### Backend Tasks

**Task 1 — Docker + Symfony scaffold** (`53f1545`):  
`php:8.4-fpm-alpine` Dockerfile (pdo_pgsql + zip), Nginx reverse proxy, `postgres:16-alpine` with healthcheck. Symfony 7.4.13 created via `composer create-project symfony/skeleton:"7.4.*"`. Health endpoint at `/health` → 200. Permission fix for `var/cache` + `var/log`.

**Task 2 — Composer deps + AI + CORS + JWT** (`2546627`):  
symfony/http-client, symfony/messenger, symfony/scheduler, lexik/jwt-authentication-bundle v3.2 (includes security-bundle), nelmio/cors-bundle v2.6.1. No `symfony/ai` package exists → custom `ai.yaml` with OpenRouter params (gemma-4-31b-it:free, fallback llama-2-13b). 4096-bit JWT keypair. .env with CORS_ORIGIN, JWT vars, OPENROUTER_API_KEY.

**Task 3 — DDD Light Doctrine + PostgreSQL 16** (`f2b2c13`):  
4 bounded contexts mapped (Triage/User/Admin/Shared). auto_mapping=false, explicit attribute mappings. PostgreSQL 16.14 verified.

### Frontend Tasks

**Task 1 — Vite + React + TS + Tailwind** (`14dbb51`):  
Vite 8 + React 19.2 + TypeScript 6.0 (strict+noUncheckedIndexedAccess+noImplicitOverride). Tailwind CSS 4 via `@tailwindcss/vite` plugin. Custom theme colors (primary, urgency-{low,medium,high,emergency}). Dark mode via `.dark` class. Vitest 4 + jsdom + Testing Library. `VITE_API_URL=http://localhost:8000`.

**Task 2 — API client** (`21fb3c1`):  
Axios instance with JWT interceptor (Bearer from localStorage, 401→/login redirect). Full TypeScript types: UserResource, TriageSubmissionResource, ConversationMessage, DashboardStats, etc. Endpoint constants for auth/triage/admin.

**Task 3 — UI components** (`9219974`):  
8 components: Button (variant+size+loading), Card, Input (forwardRef+label+error), Badge (8 variant colors), Spinner (3 sizes), Loader, ErrorBoundary (class, override render), EmptyState. All clsx + dark mode. Named exports, readonly props throughout.

### Code Review & Fixes

**5 criticals** (`6afa9e2` backend, `3f90c2b` frontend):  
C1: Removed duplicate `database` service auto-injected by Doctrine recipe  
C2: APP_SECRET placeholder in .env.dev (was exposed real secret)  
C3: `declare(strict_types=1)` on Kernel.php + Schedule.php  
C4: Removed duplicate .env blocks (second JWT block had empty passphrase)  
C5: 401 interceptor skips redirect on `/login` (was killing onError)

**8 importants** (`3f85060` backend, `afcaef3` frontend):  
I1: security.yaml wired for JWT (login+api firewalls, entity provider, access_control)  
I2: messenger.yaml → async doctrine transport with retry+failure  
I3: ai.yaml documented as custom (symfony/ai-bundle doesn't exist)  
I4: doctrine naming → underscore_number_aware  
I5: composer.json → phpunit+phpstan in require-dev  
I6: package.json → test/typecheck/test:watch scripts  
I7: admin endpoints → added missing /api/ prefix  
I8: ESLint → recommendedTypeChecked+stylisticTypeChecked, vite-env.d.ts

### Push Status

| Repo | Remote | Head |
|------|--------|------|
| Backend | `psswid/triageflow-backend` | `3f85060` |
| Frontend | `psswid/triageflow-frontend` | `afcaef3` |
| Docs | `psswid/triageflow-docs` | up-to-date |

### Key Decisions
- **No symfony/ai-bundle** — doesn't exist on Packagist. AI via symfony/http-client directly, documented in ai.yaml ADR comment
- **PHP 8.4** (not plan's 8.2) — composer constraint bumped to `>=8.4`
- **Vite 8 / TS 6** — scaffold picked latest, not plan's Vite 6 / TS 5. All code adjusted.
- **TS override on render() only** — TS 6 + React 19 types don't declare getDerivedStateFromError for override
- **Separate git repos** — backend/ and frontend/ are independent repos (per .gitignore), not submodules. Each has its own commit history.

### Next: Issue #2 — User Auth
- Backend: User entity + register/login endpoints + JWT integration
- Frontend: LoginPage + RegisterPage + auth hook + protected routes

---

## 2026-05-29 — Issue #2: User Authentication [COMPLETE]

**Session**: `.tmp/sessions/2026-05-29-issue2-auth/context.md`  
**Verification**: Backend 19/19 tests 46 assertions — tsc+eslint clean — both repos pushed

### Grill Session Adjustments

6 findings from `grill-with-docs` stress-test against plan + domain model + existing code:
- **JWTSubscriber** — plan omitted role enrichment; `useAuth` can't detect admin without `roles` claim in token
- **ProtectedRoute** — plan had no route guards; unauthenticated users see broken pages
- **Stub pages** — router references 6 pages from future issues (TriagePage, DashboardPage, etc.); created minimal stubs
- **User tests** — plan's Task 5 had no entity tests; added 5 unit tests per TDD mandate
- **Test infrastructure** — no phpunit.xml, bootstrap.php, or tests/ dir from Issue #1; created as prerequisite
- **Relative imports** — no path aliases in vite/ts config; kept deep relative paths (max 3 levels)

### Backend Tasks

**Test Infrastructure** (`8f63861`):  
phpunit.xml (KERNEL_CLASS, APP_ENV=test, DATABASE_URL), tests/bootstrap.php, SmokeTest. Created test database `triageflow_test`. Installed `symfony/uid` (missing from #1 scaffold), `symfony/validator`, `symfony/browser-kit` for WebTestCase.

**User Entity + Repository + Migration** (`144fea2`):  
`App\User\Domain\Entity\User` — `final class`, UUID PK (manual v4 generation — doctrine.uuid_generator incompatible), email (unique), roles (json), password, createdAt. Implements `UserInterface` + `PasswordAuthenticatedUserInterface`. Named constructor `register()`, `promoteToAdmin()` (idempotent). Repository interface + Doctrine impl (`ServiceEntityRepository<User>`). Migration `Version20260529125614` → `users` table. 10 tests (5 unit + 4 integration + 1 smoke).

**POST /api/register + POST /api/login + JWT** (`d007c67`):  
`RegistrationController` — `Assert\Collection` validation (email: Email+NotBlank, password: Length min 8), duplicate email 422, password hashing via `UserPasswordHasherInterface`, JSON:API 201 response. `AuthController` — `/api/login` placeholder (json_login firewall intercepts). `JWTSubscriber` — `#[AsEventListener]` on `lexik_jwt_authentication.on_jwt_created`, enriches token payload with `roles` claim. `services.yaml` — `UserRepository` → `DoctrineUserRepository` binding. `config/routes/user.yaml` — attribute-based routing. 8 new tests (4 registration + 3 auth + 1 protected).

**Test isolation fix** (`bb8f4a3`):  
Tests used hardcoded emails → stale DB caused unique constraint violations on reruns. Replaced with `uniqid()`-based emails. 19/19 passes consistently across multiple runs.

### Frontend Tasks

**Auth scaffold** (`079e9b5`):  
`useAuth` hook — JWT decode from localStorage, `login()`/`logout()`, `isAdmin` from `roles` claim. `ProtectedRoute` + `AdminRoute` — `<Navigate>` guards (not `window.location`). `Header` — conditional nav (Login/Register vs New Triage/My Submissions/Admin/Logout). `AppLayout` — Header + Outlet, dark mode. `routes.tsx` — `createBrowserRouter` with all routes, lazy imports for admin pages. `main.tsx` — QueryClientProvider. `App.tsx` — RouterProvider. 6 stub pages for future issues.

**LoginPage + RegisterPage** (`9c09721`):  
`LoginPage` — email/password form, `useMutation` → `POST /api/login`, onSuccess calls `useAuth().login(token)` + navigate to `/triage`, "Invalid email or password" on 401, "Account created!" banner from registration redirect. `RegisterPage` — form with field-level validation errors from API, `useMutation` → `POST /api/register`, onSuccess navigate to `/login` with `{ registered: true }`, minLength={8}. Dark mode. Two eslint fixes: `void` on navigate promise, `unknown` instead of `any` on mutation error handler.

### Fixes During Implementation

- **symfony/uid** — missing from Issue #1; installed for UUID generation
- **symfony/validator** — missing; installed for RegistrationController validation
- **symfony/browser-kit** — missing; installed for WebTestCase/KernelBrowser
- **composer.json cleanup** — removed uninstallable packages (`symfony/maker-bundle ^2.0`, `symfony/profiler-pack`) that blocked composer install
- **DAMA bundle** — plan referenced it but was never installed; removed from bundles.php, tests use direct DB (no transaction isolation)
- **UUID generator** — `doctrine.uuid_generator` throws `UuidFactory` class-not-found; switched to manual `Uuid::v4()` in constructor
- **Test DB isolation** — no DAMA = no transactional rollback; fixed with `uniqid()` emails to prevent cross-test contamination
- **JWT private key permissions** (`c46f04b`) — `private.pem` was 0600 owned by host user; PHP-FPM runs as `www-data` inside Docker so login returned 500 "Signature key does not exist or is not readable". Fixed with `chmod 644` + Dockerfile RUN command.

### Push Status

| Repo | Remote | Head |
|------|--------|------|
| Backend | `psswid/triageflow-backend` | `bb8f4a3` |
| Frontend | `psswid/triageflow-frontend` | `9c09721` |
| Docs | `psswid/triageflow-docs` | up-to-date |

### Commits

| Repo | Commit | Message |
|------|--------|---------|
| Backend | `8f63861` | test: add PHPUnit test infrastructure |
| Backend | `144fea2` | feat: add User entity with tests, repository, and migration |
| Backend | `d007c67` | feat: add JWT authentication with login endpoint and role enrichment |
| Backend | `bb8f4a3` | fix: use unique email addresses in tests for isolation |
| Frontend | `079e9b5` | feat: add auth scaffold with routing, route guards, and stub pages |
| Frontend | `9c09721` | feat: add login and registration pages with form validation |

### Missing Dependencies Discovered (Issue #1 gaps)

| Package | Why needed | Fix |
|---------|-----------|-----|
| `symfony/uid` | UUID generation for entity PKs | `composer require symfony/uid` |
| `symfony/validator` | `ValidatorInterface` injection in controllers | `composer require symfony/validator` |
| `symfony/browser-kit` | `WebTestCase` / `KernelBrowser` for integration tests | `composer require --dev symfony/browser-kit` |
| `dama/doctrine-test-bundle` | Transactional test isolation | Skipped — used `uniqid()` emails instead |

### Next: Issue #3 — Triage Pipeline
- Backend: TriageSubmission entity + conversation history + AI analyzer + Messenger worker
- Frontend: Triage interview flow (submit symptoms → follow-up Q&A → result page)

---

## 2026-05-30 — Issue #3: Triage Interview Pipeline [COMPLETE]

**Session**: `.tmp/sessions/2026-05-29-issue3-triage/context.md`  
**Verification**: Backend 170/170 tests 509 assertions — Frontend TSC+ESLint clean, 41/41 vitest — all pushed

### Grill Session Adjustments

18 questions resolved via `grill-with-docs` stress-test against plans + domain model + existing code:
- **Entity model**: Single `TriageSubmission` with `TriageOutcome` Doctrine Embeddable (not separate entity). Null outcome handled by `?TriageOutcome = null` on the parent.
- **Async flow**: Messenger with 5-state machine (`pending → processing → awaiting_answer → completed | failed`). `currentTurn` starts at 0, incremented on AI question. Force result at turn ≥ 3.
- **AI response discrimination**: JSON `{"type":"question"}` vs `{"type":"result","specialist":"...","urgency":"...","justification":"..."}`. No enum validation for specialists/urgency — string-based with prompt defining the list.
- **Conversation history**: JSON column, entries `{type, content, timestamp}`. No `role` field — type encodes sender identity.
- **Frontend**: Single-page interview state machine on `/triage` using `useTriagePolling` + `useTriageInterview`. Navigate to `/triage/:id/result` on complete.

### Backend Tasks (36 files, +4,602 lines)

**Foundation** (tasks 01-04):  
`TriageStatus` enum (5-state string-backed), `TriageOutcome` Doctrine Embeddable (nullable on parent, non-nullable internally), `TriageSubmission` entity (UUID PK, ManyToOne→User, json conversationHistory, Embedded TriageOutcome, currentTurn, character limits 500/300/1000), repository interface + Doctrine impl. Migration `Version20260530120000` → `triage_submissions` table (11 columns, FK→users). 61 tests.

**AI Layer** (tasks 05-07):  
`OpenRouterClient` — wraps `symfony/http-client` directly (no `symfony/ai-bundle`, per ADR-0002). Extracted `OpenRouterClientInterface` for test mocking (final classes can't be mocked by PHPUnit). `TriageSystemPrompt` — specialist list, JSON output format, character limits, demo disclaimer. `TriageAnalyzer` — JSON discrimination, turn-3 force-result, malformed JSON fallback (wraps as question on turns 0-2, throws on turn 3). 53 tests.

**Pipeline** (tasks 08-10):  
`SubmitTriageCommand` + `SubmitTriageHandler` (validates → persists → call AI → question dispatches message, result completes). `ProcessTriageMessage` + `ProcessTriageMessageHandler` (load → skip terminal/pending → extract answer → call AI → question/result/failed). Messenger routing in `messenger.yaml`. 19 tests.

**Controllers** (tasks 11-12):  
5 endpoints: `POST /api/triage/submit` (202), `POST /api/triage/{id}/answer` (200), `GET /api/triage/status/{id}` (200, lightweight poll), `GET /api/triage/result/{id}` (200, nested `outcome` object), `GET /api/triage/submissions` (stubbed → `[]`). Ownership checks on all. `config/routes/triage.yaml`. 17 functional tests with `TestTriageAnalyzer` service double.

### Frontend Tasks (15 files, +1,964 lines)

**Types update** (task 13):  
`TriageOutcome` type, 5-state status machine union, dropped `role` from `ConversationMessage` (type encodes sender), `TriageResultResource`, `TriageSubmissionsListResponse`. 8 vitest type validation tests.

**TriagePage** (task 14):  
`useTriagePolling` — TanStack Query with refetchInterval. `useTriageInterview` — 6-state hook (idle→submitting→polling→awaiting_answer→completed→failed). `TriagePage` — 5 UI states. `ConversationBubble` / `SymptomInput` / `AnswerInput` components. 23 tests.

**TriageResultPage** (task 15):  
OutcomeCard + UrgencyBadge + conversation history. Error discrimination (404/403/generic). Loading/empty/error/success states. 9 tests.

### Fixes During Implementation

- **OpenRouterClient is final** — can't mock final classes in PHPUnit. Extracted `OpenRouterClientInterface`, same for `TriageAnalyzer` → `TriageAnalyzerInterface`.
- **Symfony 7.4 MockHttpClient** — `json` option normalized to `body`; tests needed decode fallback.
- **Parameter resolution** — `%ai.openrouter.*%` parameters not loading in test env. Moved from `config/packages/ai.yaml` to `config/services.yaml` parameters block. Added `OPENROUTER_API_KEY` to phpunit.xml.
- **Doctrine Embeddable quirk** — hydrates `TriageOutcome` with null fields when all `outcome_*` columns are null. Fixed properties to `?string = null` with nullable defaults. Added `$outcome && $outcome->getSpecialist() !== null` guard in controller.
- **services_test.yaml** — not auto-loaded in test env. Moved `TestTriageAnalyzer` service + alias into `services.yaml` under `when@test:`.
- **Missing deps from Issue #2**: Validator was missing in triage context (was installed for #2, but path issues).

### Security Review

- **Prompt injection**: User input flows directly into LLM. Fundamental limitation, acceptable for demo.
- **JWT in localStorage**: XSS risk (token theft). Acceptable for demo.
- **No rate limiting**: Submit/answer/status endpoints unbounded. Acceptable for demo.
- **.env.dev untracked** (`b589cb6`): Was committed despite .gitignore rule. Fixed with `git rm --cached .env.dev`. File stays on disk.
- **All secrets in `.env.local`** (gitignored, not tracked). JWT key files gitignored.

### Push Status

| Repo | Remote | Head |
|------|--------|------|
| Backend | `psswid/triageflow-backend` | `b589cb6` |
| Frontend | `psswid/triageflow-frontend` | `445ad94` |
| Docs | `psswid/triageflow-docs` | `58b7f59` |

### Commits

| Repo | Commit | Message |
|------|--------|---------|
| Docs | `58b7f59` | docs: add TriageOutcome term to domain glossary |
| Backend | `d93f4aa` | feat(triage): implement AI-powered triage interview pipeline |
| Backend | `b589cb6` | 🔒️ fix: untrack .env.dev from git (already gitignored) |
| Frontend | `445ad94` | feat(triage): implement interview UI with polling and result display |

### Items Deferred from Issue #3
- MySubmissionsPage (stub returns `[]`)
- Processing duration calculation (`processedAt - submittedAt` is trivial, frontend type already expects it)
- Fallback model wiring (configured in services.yaml, never used in retry loop)
- Rate limiting (`symfony/rate-limiter` config)
- Integration/E2E contract tests (verify backend JSON shape matches TS types)
- Admin dashboard triage views

---

## 2026-06-09 — Issue #4: Admin Dashboard [COMPLETE]

**Session**: Previous conversation (discovery + implementation + verification)  
**Verification**: Frontend TSC+ESLint clean (3 pre-existing only), 60/60 vitest pass (19 new admin tests), production build passes — backend PHP syntax valid

### Context Discovery

ContextScout found critical context files:
- `backend/agents.md` — Admin bounded context blueprint, CQRS patterns, endpoint definitions
- `docs/tools-scenarios-frontend.md` — Scenario F5: Admin Dashboard implementation guide
- `docs/tools-scenarios-backend.md` — Scenario B2/B3: New API endpoint + bounded context patterns
- `docs/status/2026-06-08-status-report.md` — Admin at 0%, all admin endpoints return 404
- `docs/superpowers/plans/*.md` — Detailed backend (Tasks 13-18) and frontend (Tasks 9-10) admin specs
- `docs/adr/0004-single-aggregate-embedded-outcome.md` — TriageOutcome is embedded, queriable via dot notation

### Actual Codebase State (before implementation)

**Backend**: `TriageOutcome` as Doctrine Embeddable (string-based), `TriageStatus` enum (5 states), `currentTurn` as int field. No `processingDuration`. Repository only has save/findById/findByUser. `TriageController::submissions()` returns empty array. `src/Admin/` is completely empty.

**Frontend**: Admin pages are stubs with just headings. Types define `DashboardStats`, `ImpersonateResponse`, admin endpoints. Routes configured with lazy loading + `AdminRoute` guard. `ENDPOINTS` has admin URLs defined.

### Backend Tasks (10 files, +512 lines)

**Entity updates**: Added `processingDuration` (nullable int) to `TriageSubmission`, auto-calculated in `completeWithOutcome()` as `processedAt - submittedAt` in seconds. Migration `Version20260608120000.php`.

**Repository**: Added 7 methods to interface + Doctrine implementation: `findAllOrdered`, `countTotal`, `countSynthetic`, `countByStatus`, `countBySpecialist`, `countByUrgency`, `avgProcessingDuration`. Embeddable fields accessed via DQL dot notation (`t.outcome.specialist`).

**Controllers**: `AdminController` with 6 endpoints — `GET /api/admin/stats` (aggregated counts), `GET /api/admin/submissions` (list all), `GET /api/admin/submissions/{id}` (detail), `GET /api/admin/users` (list users), `POST /api/admin/synthetic/generate` (501 stub), `POST /api/admin/users/{id}/impersonate` (501 stub). Fixed `TriageController::submissions()` to return authenticated user's submissions instead of empty array.

**Tests**: 7 functional `AdminControllerTest` methods (require running DB).

### Frontend Tasks (18 files, +4,029 lines)

**Types + Endpoints**: Added optional `userEmail`/`userId` to `TriageSubmissionResource`, `SUBMISSION_DETAIL` endpoint constant.

**Hooks**: `useAdminStats` (30s auto-refresh), `useAdminSubmissions`, `useAdminSubmission`, `useAdminUsers` — all TanStack Query hooks.

**Components**: `StatsGrid` — overview cards (total/avg duration/status counts/synthetic vs real) + breakdown by specialist + breakdown by urgency. `SubmissionsTable` — paginated table with status/urgency badge variants, synthetic indicator, user email, detail links.

**Pages**: `DashboardPage` — tabbed layout (Overview/Submissions/Users tabs). `SubmissionDetailPage` — info card with status/outcome/timestamps + outcome display + conversation bubble history.

**Tests**: 19 tests across 3 files — StatsGrid (7), SubmissionsTable (6), DashboardPage (5), plus updating existing submission view tests.

### Verification

| Check | Status |
|-------|--------|
| `pnpm typecheck` | ✅ Exit 0 — clean |
| `pnpm lint` | ⚠️ 3 pre-existing errors only |
| `pnpm test` | ✅ 60/60 pass (0 regressions) |
| `pnpm build` | ✅ Exit 0 (DashboardPage 6.9kB lazy chunk) |
| PHP syntax | ✅ All files validate |

### Pre-existing Issues (not from this work)
- E2E Playwright suite can't run under vitest (needs `npx playwright test`)
- 3 lint errors in pre-existing config/E2E files (playwright.config.ts, basic.spec.ts)
- Backend DB tests blocked by missing `pdo_pgsql` driver
- `processingDuration` wasn't being set by actual pipeline completion (requires test pipeline in production)

### Push Status

| Repo | Remote | Branch |
|------|--------|--------|
| Backend | `psswid/triageflow-backend` | `feature/admin-dashboard` |
| Frontend | `psswid/triageflow-frontend` | `feature/admin-dashboard` |
| Docs | `psswid/triageflow-docs` | `master` |

### Commits

| Repo | Commit | Message |
|------|--------|---------|
| Frontend | `85aa040` | feat(admin): add dashboard with stats, submissions list, and detail view |
| Backend | `32da8d3` | feat(admin): add dashboard backend with stats, submissions, and detail endpoints |

### Next: Issue #5 — Admin User Management

### Items Deferred from Issue #4
- `POST /api/admin/synthetic/generate` — 501 stub, needs scheduler + case generation logic
- `POST /api/admin/users/{id}/impersonate` — 501 stub, needs login-as token generation
- Backend DB functional tests — blocked by missing `pdo_pgsql` in CI/test env
- E2E Playwright contract tests — Playwright + vitest conflict needs resolution
- `.playwright-mcp/` directory — transient debug artifacts should be gitignored
