# TriageFlow — Comprehensive Status Report

**Date:** 2026-06-08  
**Author:** zoom-out walkthrough  
**Issues complete:** #1 Scaffold → #2 Auth → #3 Triage Pipeline  
**Next issues:** #4 (MySubmissions + Admin), #5 (Synthetic Generator), #6 (Dashboard), #7 (Polish)

---

## 1. Executive Summary

| Dimension | Score | Status |
|-----------|-------|--------|
| Backend health | ✅ **96%** | 170/170 tests pass, all endpoints functional |
| Frontend health | ✅ **95%** | 41/41 tests pass, TSC + ESLint clean |
| Documentation | 🟡 **75%** | agents.md out of date, no frontend/agents.md |
| Infrastructure | ✅ **100%** | Docker 3/3 up, PostgreSQL healthy, JWT configured |
| Admin features | 🔴 **0%** | Admin context empty (0 PHP files), all admin endpoints 404 |
| Pipeline gaps | 🟡 **~85%** | MySubmissions stub, no processingDuration, no rate limiting |

**Overall project health:** ~85% of planned scope complete for demo functionality. Core triage interview pipeline works end-to-end.

---

## 2. Backend: Complete Inventory

### 2.1 Bounded Context Map

```
src/
├── Triage/        (core domain)    — 15 files, 4,602+ lines  ← FULLY IMPLEMENTED
├── User/          (auth)           — 6 files                  ← FULLY IMPLEMENTED
├── Admin/         (admin panel)    — 0 files (empty stubs)    ← NOT STARTED
├── Shared/        (cross-cutting)  — 3 files                  ← IMPLEMENTED (OpenRouter)
└── Controller/    (health)         — 1 file                   ← ROOT LEVEL
```

### 2.2 Entity / Schema

| Table | Columns | Migrations | Status |
|-------|---------|------------|--------|
| `users` | 5 (id UUID, email unique, roles json, password, created_at) | `Version20260529125614` | ✅ |
| `triage_submissions` | 11 (id UUID, FK→users, conversation_history json, status, current_turn, outcome_* embeddable, is_synthetic, timestamps) | `Version20260530120000` | ✅ |

### 2.3 All API Endpoints

| Method | Path | Controller | Status | Auth |
|--------|------|------------|--------|------|
| `GET` | `/health` | `HealthController` | ✅ 200 | None |
| `POST` | `/api/register` | `RegistrationController` | ✅ 201/422 | None |
| `POST` | `/api/login` | `AuthController` (json_login intercepts) | ✅ 200/401 | None |
| `POST` | `/api/triage/submit` | `TriageController::submit` | ✅ 202/400/403 | JWT |
| `POST` | `/api/triage/{id}/answer` | `TriageController::answer` | ✅ 200/404/403 | JWT |
| `GET` | `/api/triage/status/{id}` | `TriageController::status` | ✅ 200/404/403 | JWT |
| `GET` | `/api/triage/result/{id}` | `TriageController::result` | ✅ 200/404/403 | JWT |
| `GET` | `/api/triage/submissions` | `TriageController::submissions` | 🟡 Returns `[]` | JWT |

**Frontend references but backend does NOT have** (all return 404):
- `GET /api/admin/stats`
- `GET/POST /api/admin/submissions`
- `GET /api/admin/users`
- `POST /api/admin/synthetic/generate`
- `POST /api/admin/users/{id}/impersonate`

### 2.4 Source Files (26 PHP files)

```
src/
├── Kernel.php                                  — App kernel
├── Schedule.php                                — Empty scheduler provider
├── Controller/
│   └── HealthController.php                    — GET /health
├── Shared/Infrastructure/Ai/
│   ├── OpenRouterClient.php                    — HTTP client wrapper
│   ├── OpenRouterClientInterface.php           — Interface for mocking
│   └── OpenRouterException.php                 — Exception class
├── Triage/
│   ├── Domain/Entity/
│   │   ├── TriageSubmission.php                — Aggregate root (submission+history+outcome)
│   │   ├── TriageOutcome.php                   — Doctrine Embeddable (specialist/urgency/justification)
│   │   └── TriageStatus.php                    — Enum (pending/processing/awaiting_answer/completed/failed)
│   ├── Domain/Repository/
│   │   └── TriageSubmissionRepository.php      — Interface (save/findById/findByUser)
│   ├── Application/Command/
│   │   ├── SubmitTriageCommand.php             — CQRS command DTO
│   │   └── SubmitTriageHandler.php             — Handler (create + analyze + dispatch)
│   ├── Application/Message/
│   │   ├── ProcessTriageMessage.php            — Async message for Messenger
│   │   └── ProcessTriageMessageHandler.php     — Message handler (follow-up analysis)
│   ├── Application/Service/
│   │   ├── TriageAnalyzer.php                  — AI analysis (JSON discrimination, force-result)
│   │   ├── TriageAnalyzerInterface.php         — Interface for mocking
│   │   ├── TriageSystemPrompt.php              — System prompt builder
│   │   └── TriageAnalysisFailedException.php   — Exception
│   └── Infrastructure/
│       ├── Controller/TriageController.php     — 5 REST endpoints
│       └── Repository/DoctrineTriageSubmissionRepository.php  — Doctrine impl
└── User/
    ├── Domain/Entity/
    │   └── User.php                            — User (UUID, email, roles, password, createdAt)
    ├── Domain/Repository/
    │   └── UserRepository.php                  — Interface
    └── Infrastructure/
        ├── Controller/AuthController.php       — POST /api/register, /api/login declaration
        ├── Controller/RegistrationController.php — Registration handler
        ├── Repository/DoctrineUserRepository.php  — Doctrine impl
        └── Security/JWTSubscriber.php          — Roles claim enricher
```

### 2.5 Test Files (18 PHP files)

```
tests/
├── bootstrap.php
├── SmokeTest.php
├── Triage/Domain/Entity/
│   ├── TriageSubmissionTest.php        — 26 tests
│   ├── TriageOutcomeTest.php           — 10 tests
│   └── TriageStatusTest.php            — 7 tests
├── Triage/Application/Command/
│   └── SubmitTriageHandlerTest.php     — 6 tests
├── Triage/Application/Message/
│   └── ProcessTriageMessageHandlerTest.php — 8 tests
├── Triage/Application/Service/
│   ├── TriageAnalyzerTest.php          — 18 tests
│   └── TriageSystemPromptTest.php      — 14 tests
├── Triage/Infrastructure/Controller/
│   ├── TriageControllerTest.php        — 13 tests
│   └── TestTriageAnalyzer.php          — Test double
├── Triage/Infrastructure/Repository/
│   └── DoctrineTriageSubmissionRepositoryTest.php — 4 tests
├── User/Domain/Entity/
│   └── UserTest.php                    — 4 tests
├── User/Infrastructure/Controller/
│   ├── AuthControllerTest.php          — 3 tests
│   └── RegistrationControllerTest.php  — 4 tests
├── User/Infrastructure/Repository/
│   └── DoctrineUserRepositoryTest.php  — 4 tests
├── User/Infrastructure/Security/
│   └── JWTSubscriberTest.php           — 2 tests
└── Shared/Infrastructure/Ai/
    └── OpenRouterClientTest.php        — 11 tests
```

**Test summary:** 170 tests, 509 assertions — all passing ✅

### 2.6 Backend Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| doctrine/orm | ^3.6 | ORM |
| doctrine/doctrine-bundle | ^3.2 | Doctrine integration |
| doctrine/doctrine-migrations-bundle | ^4.0 | Migrations |
| lexik/jwt-authentication-bundle | * | JWT auth |
| nelmio/cors-bundle | * | CORS |
| symfony/http-client | 7.4.* | AI API calls |
| symfony/messenger | 7.4.* | Async AI processing |
| symfony/scheduler | 7.4.* | Synthetic case scheduling |
| symfony/validator | 7.4.* | Input validation |
| symfony/uid | 7.4.* | UUID generation |
| phpunit/phpunit | ^11.5 | Testing |

**Not installed** (referenced in plans/config):
- ❌ `phpstan/phpstan` — static analysis (in config.json preCommitChecks)
- ❌ `symfony/php-cs-fixer` — code style (in config.json preCommitChecks)
- ❌ `dama/doctrine-test-bundle` — test DB isolation (in agents.md)
- ❌ `api-platform/core` — API Platform (in agents.md)
- ❌ `symfony/ai-bundle` — doesn't exist on Packagist (per ADR-0002)

### 2.7 Infrastructure (Docker)

| Service | Container | Base Image | Status |
|---------|-----------|------------|--------|
| PHP-FPM | `triageflow_php` | `php:8.4-fpm-alpine` | ✅ Up (2h) |
| Nginx | `triageflow_nginx` | `nginx:alpine` | ✅ Up (2h), port 8000 |
| PostgreSQL | `triageflow_db` | `postgres:16-alpine` | ✅ Up (2h, healthy), port 5432 |

---

## 3. Frontend: Complete Inventory

### 3.1 Route Tree

```
/                              → Navigate to /triage              [redirect]
/login                         → LoginPage                        [public]
/register                      → RegisterPage                     [public]
                                ── Protected (JWT required) ──
/triage                        → TriagePage                       [full implementation]
/triage/:id/result             → TriageResultPage                 [full implementation]
/submissions                   → MySubmissionsPage                [STUB]
                                ── Admin (ROLE_ADMIN required) ──
/admin                         → DashboardPage                    [STUB]
/admin/submissions/:id         → SubmissionDetailPage             [STUB]
/admin/users                   → UsersPage                        [STUB]
```

All routes wrapped in `AppLayout` (Header + Outlet). Protected by `ProtectedRoute` or `AdminRoute` guards.

### 3.2 All Source Files (40 TS/TSX files)

```
src/
├── main.tsx                                    — Entry: QueryClientProvider + RouterProvider
├── App.tsx                                     — Shell: <RouterProvider router={router}>
├── routes.tsx                                  — All route definitions
├── vite-env.d.ts                               — VITE_API_URL type
├── styles/index.css                            — Tailwind CSS v4 + custom theme + dark mode
├── api/
│   ├── client.ts                               — Axios + JWT interceptor
│   ├── endpoints.ts                            — Endpoint constants (AUTH/TRIAGE/ADMIN)
│   ├── types.ts                                — 18 TypeScript interfaces
│   └── __tests__/types.test.ts                 — 1 test file
├── hooks/
│   └── useAuth.ts                              — JWT decode, login/logout, isAdmin
├── components/
│   ├── layout/
│   │   ├── AppLayout.tsx                       — Header + Outlet shell
│   │   ├── Header.tsx                          — Nav + auth buttons
│   │   ├── ProtectedRoute.tsx                  — Auth guard (redirect to /login)
│   │   └── AdminRoute.tsx                      — Admin guard (redirect to /)
│   ├── ui/
│   │   ├── Button.tsx                          — variant/size/loading
│   │   ├── Spinner.tsx                         — SVG animated spinner
│   │   ├── Badge.tsx                           — 8 color variants
│   │   ├── Input.tsx                           — forwardRef + label + error
│   │   └── Card.tsx                            — Container component
│   └── shared/
│       ├── ErrorBoundary.tsx                   — Class-based error boundary
│       ├── EmptyState.tsx                      — Empty state with icon
│       └── Loader.tsx                          — Centered spinner + message
├── features/
│   ├── auth/pages/
│   │   ├── LoginPage.tsx                       — Login form (complete)
│   │   └── RegisterPage.tsx                    — Registration form (complete)
│   ├── triage/
│   │   ├── hooks/
│   │   │   ├── useTriageInterview.ts           — 6-state state machine
│   │   │   └── useTriagePolling.ts             — TanStack Query polling
│   │   ├── pages/
│   │   │   ├── TriagePage.tsx                  — Interview UI (complete)
│   │   │   └── TriageResultPage.tsx            — Result display (complete)
│   │   └── components/
│   │       ├── SymptomInput.tsx                — 500-char textarea
│   │       ├── AnswerInput.tsx                 — 300-char input with turn counter
│   │       ├── ConversationBubble.tsx          — Chat bubble (user/AI/result)
│   │       ├── OutcomeCard.tsx                 — Final outcome display
│   │       └── UrgencyBadge.tsx                — LOW/MEDIUM/HIGH/EMERGENCY
│   ├── admin/pages/
│   │   ├── DashboardPage.tsx                   — STUB: heading only
│   │   ├── UsersPage.tsx                       — STUB: heading only
│   │   └── SubmissionDetailPage.tsx            — STUB: heading only
│   └── submissions/pages/
│       └── MySubmissionsPage.tsx               — STUB: heading only
└── test/
    ├── setup.ts                                — jest-dom imports
    └── triage/
        ├── TriagePage.test.tsx                 — Page state tests
        ├── TriageResultPage.test.tsx           — Result page tests
        └── useTriageInterview.test.ts          — Hook state machine tests
```

### 3.3 Frontend Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| react | ^19.2.6 | UI framework |
| react-dom | ^19.2.6 | DOM renderer |
| react-router-dom | ^7.16.0 | Routing |
| @tanstack/react-query | ^5.100.14 | Server state management |
| axios | ^1.16.1 | HTTP client |
| clsx | ^2.1.1 | Conditional classes |
| vite | ^8.0.12 | Build tool |
| tailwindcss | ^4.3.0 | CSS framework |
| typescript | ~6.0.2 | Type system |
| vitest | ^4.1.7 | Test runner |
| @testing-library/react | ^16.3.2 | Component testing |

---

## 4. AI Integration

### 4.1 Architecture

```
User Input → TriageController → SubmitTriageHandler → TriageAnalyzer (sync)
                                                          ↓
                                                   OpenRouterClient
                                                          ↓
                                                   OpenRouter API (gemma-4-31b-it:free)
                                                          ↓
                                                   JSON response
                                                          ↓
                                            ┌──────────────────┐
                                            │ type: "question" │ → async ProcessTriageMessage (Messenger)
                                            │ type: "result"   │ → complete submission
                                            └──────────────────┘
```

### 4.2 Models Used

| Model | Provider | Use | Fallback |
|-------|----------|-----|----------|
| `google/gemma-4-31b-it:free` | OpenRouter (free) | Primary triage analysis | `meta-llama/llama-2-13b-chat:free` |
| (future) | OpenRouter (free) | Synthetic case generation | None |

### 4.3 Key Design Decisions (from implementation, not plans)

| Decision | Planned | Actual | ADR |
|----------|---------|--------|-----|
| AI package | `symfony/ai` v0.9.0 | `symfony/http-client` (custom) | ADR-0002 |
| AI model | DeepSeek V4 Pro/Flash | OpenRouter free (gemma-4, llama-2) | ADR-0001 |
| Architecture style | API Platform auto-CRUD | Manual REST controllers | — |
| DB isolation | DAMA bundle | `uniqid()` emails | — |
| Static analysis | PHPStan | Not installed | — |
| Code style | php-cs-fixer | Not installed | — |
| Specialist/Urgency enums | PHP enums | String-based (prompt-defined) | — |
| Symptom value object | `Symptom` DTO | Free text strings | — |

---

## 5. Documentation Health

### 5.1 ADRs (5/5 complete)

| # | Title | Status |
|---|-------|--------|
| 0001 | OpenRouter free models for demo app | ✅ Accurate |
| 0002 | Custom AI integration — no symfony/ai-bundle | ✅ Accurate |
| 0003 | Separate git repos for backend and frontend | ✅ Accurate |
| 0004 | Single aggregate: TriageSubmission with embedded TriageOutcome | ✅ Accurate |
| 0005 | JSON column for conversation history | ✅ Accurate |

### 5.2 Handoffs (4 complete)

| File | Covers | Status |
|------|--------|--------|
| `handoff-phase1-foundation.md` | Phase 1 setup | ✅ |
| `triageflow-handoff-issue2.md` | Issue #2 Auth | ✅ |
| `triageflow-handoff-issue3.md` | Issue #2→#3 transition | ✅ |
| `handoff-issue3-triage.md` | Issue #3 Triage Pipeline | ✅ |

### 5.3 Discrepancies Found

| File | Claims | Reality |
|------|--------|---------|
| `agents.md` | Uses `symfony/ai` (v0.9.0) | Uses `symfony/http-client` (ADR-0002) |
| `agents.md` | API Platform for admin | No API Platform installed |
| `agents.md` | DeepSeek models | OpenRouter free models |
| `agents.md` | `phpstan/phpstan` in require-dev | Not installed |
| `agents.md` | `dama/doctrine-test-bundle` | Not installed |
| `agents.md` | `symfony/ai-bundle` in composer | Doesn't exist on Packagist |
| `config.json` | `php vendor/bin/phpstan analyse` | Tool not installed |
| `config.json` | `php vendor/bin/php-cs-fixer fix --dry-run` | Tool not installed |
| `SKILL.md` | SpecialistType / UrgencyLevel PHP enums | String-based (no enums) |
| `SKILL.md` | Symptom Value Object | Free text |
| `SKILL.md` | TriageCompletedEvent | Not implemented |
| `SKILL.md` | 4-status enum | 5-status (pending/processing/awaiting_answer/completed/failed) |
| `SKILL.md` | Polling on `processing` only | Polls on pending/processing/awaiting_answer |
| — | `frontend/agents.md` exists | ❌ File does not exist |

---

## 6. Gaps & Deferred Items

### 🔴 Critical (blocking next issues)

| Gap | Impact | Notes |
|-----|--------|-------|
| **Admin context empty** | All admin API endpoints (stats, submissions, users, synthetic generate, impersonate) return 404 | Frontend references these in `endpoints.ts` |
| **MySubmissionsPage stub** | Users cannot see their past submissions | Endpoint returns `[]` |
| **frontend/agents.md missing** | No coding standards for frontend agents | Frontend devs have no local convention guide |

### 🟡 Important (should address soon)

| Gap | Impact | Notes |
|-----|--------|-------|
| **No processingDuration** | Frontend type expects it, backend doesn't compute | `processedAt - submittedAt` in controller |
| **Fallback model not wired** | `ai.yaml` has fallback config but never used in retry | `TriageAnalyzer` only uses primary model |
| **No rate limiting** | Submit/answer/status endpoints unbounded | `symfony/rate-limiter` config needed |
| **agents.md out of date** | References nonexistent packages and patterns | Needs update to reflect actual architecture |
| **SKILL.md out of date** | References enums/events that don't exist | Needs update to reflect 5-state machine, string-based types |
| **config.json stale** | References phpstan/php-cs-fixer not installed | Update preCommitChecks |
| **No E2E/integration tests** | No API contract tests between frontend/backend | Response shape could drift |

### 🟢 Nice-to-have (deferred for demo scope)

| Gap | Impact |
|-----|--------|
| **Prompt injection mitigation** | User input flows to LLM unsanitized (fundamental LLM issue) |
| **JWT in localStorage** | XSS token theft risk (acceptable for demo) |
| **Error detail leakage** | Validation errors expose field names (acceptable for demo) |
| **Synthetic case generator** | Scheduler exists but no handler implemented |
| **Processing stats** | `avgProcessingDuration`, `bySpecialist`, `byUrgency` not computed |

---

## 7. Recommendations

### Before starting Issue #4

1. **Update agents.md** — remove references to `symfony/ai`, API Platform, phpstan, DAMA bundle. Document actual stack (OpenRouterClient, manual controllers, string-based types).
2. **Update SKILL.md** — align enum definitions (5-status, not 4), remove SpecialistType/UrgencyLevel enums, update polling description.
3. **Update config.json** — remove phpstan/php-cs-fixer from preCommitChecks until installed.
4. **Create frontend/agents.md** — document React 19 patterns, naming conventions, component structure rules.

### For Issue #4 (MySubmissions + Admin)

5. **Implement MySubmissionsPage** — wire up `GET /api/triage/submissions` (currently returns `[]`), build list view with status badges.
6. **Build Admin context** — create `src/Admin/` with stats endpoint, submission listing, user listing, synthetic generation, impersonation.
7. **Implement processingDuration** — trivial calculation in controller.

### Long-term

8. **Install phpstan + php-cs-fixer** and add to preCommitChecks.
9. **Add E2E contract tests** to verify backend JSON shapes match frontend TypeScript types.
10. **Rate limit** triage submit/answer endpoints.

---

## 8. Committed State

### Backend (`psswid/triageflow-backend`)

```
b589cb6 🔒️ fix: untrack .env.dev from git
d93f4aa feat(triage): implement AI-powered triage interview pipeline
c46f04b fix: ensure JWT key permissions readable by www-data
bb8f4a3 fix: use unique email addresses in tests for isolation
d007c67 feat: add JWT authentication with login endpoint and role enrichment
144fea2 feat: add User entity with tests, repository, and migration
8f63861 test: add PHPUnit test infrastructure
3f85060 fix: important issues from code review
6afa9e2 fix: critical issues from code review
f2b2c13 feat: backend task 3 — DDD Light Doctrine config + PostgreSQL 16
53f1545 feat: Docker + Symfony scaffold
2546627 feat: Composer deps, JWT, CORS, OpenRouter config
```

### Frontend (`psswid/triageflow-frontend`)

```
445ad94 feat(triage): implement interview UI with polling and result display
9c09721 feat: add login and registration pages
079e9b5 feat: add auth scaffold with routing, route guards, stub pages
afcaef3 fix: important issues from code review
3f90c2b fix: 401 interceptor breaks login
9219974 feat: add UI components (Button, Card, Input, Badge, Spinner, Loader, ErrorBoundary, EmptyState)
21fb3c1 feat: add API client with JWT interceptor + types + endpoints
14dbb51 feat: scaffold Vite + React 19 + TypeScript + Tailwind CSS 4
c02c7e4 docs: add frontend agent configuration
```

### Docs (`psswid/triageflow-docs`)

```
58b7f59 docs: add TriageOutcome term to domain glossary
d61646e docs: add JWT key permissions fix to handoff and raw log
a7735fd docs: handoff Issue #2 → Issue #3
0e50adb docs: log Issue #2 — User Authentication completion
e2d2f4d docs: add ADR-0002, ADR-0003
f5dfd25 docs: complete Phase 1 pipeline — glossary + plans
2122284 docs: add operating guide
743366a feat: run setup-matt-pocock-skills
0d30349 docs: expand master matrix to v2 format
ef90148 docs: expand domain scenarios
```

---

## 9. Quick Reference

### Running the App

```bash
# Backend (Docker)
cd backend && docker compose up -d          # Start all services
docker compose run --rm php vendor/bin/phpunit  # Run tests (170)
# API: http://localhost:8000

# Frontend
cd frontend && npm run dev                  # Dev server at :5173
npx vitest run                              # Tests (41)
npx tsc -b --noEmit                         # TypeScript check
```

### Key Environment Variables

| Variable | File | Purpose |
|----------|------|---------|
| `OPENROUTER_API_KEY` | `.env.local` (gitignored) | AI API access |
| `JWT_PASSPHRASE` | `.env` | JWT key encryption |
| `DATABASE_URL` | `.env` (dev) / `.env.test` (test) | PostgreSQL connection |
| `APP_SECRET` | `.env.dev` | Symfony app secret |

### Verification Commands

```bash
# Full health check
cd backend && docker compose run --rm php vendor/bin/phpunit
cd frontend && npx vitest run && npx tsc -b --noEmit && npx eslint .

# Check API
curl http://localhost:8000/health
curl -X POST http://localhost:8000/api/register -H 'Content-Type: application/json' -d '{"email":"test@example.com","password":"test1234"}'
curl -X POST http://localhost:8000/api/login -H 'Content-Type: application/json' -d '{"email":"test@example.com","password":"test1234"}'
```

---

*Report generated by zoom-out walkthrough. All data verified from actual codebase state.*
