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
