# TriageFlow — Backend Scenarios

> Symfony 7.4 + Doctrine + symfony/ai + DDD Light — every backend scenario, every tool, every gate.
> Load `backend/agents.md` before any backend work.
> Origin tags: 🦸 Superpowers | 🧔 Matt Pocock | 🏠 Project (triageflow)

---

## Scenario B1: New Entity + Repository

**When:** Adding a new domain concept (e.g., `PatientProfile`, `AuditLog`) that needs persistence.
**Success:** Entity with UUID PK, PHP 8.4 enums, `isSynthetic` flag, Doctrine migration generated and tested.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🧠 Orient | Load `backend/agents.md`, find existing DDD patterns, check which bounded context this belongs to | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define entity domain language, add to `CONTEXT.md`, confirm naming matches conventions (`{DomainConcept}` not `{DomainConcept}Entity`) | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | Entity class (`final`, `readonly`, `#[ORM\Entity]`, `#[ORM\Table]`), Value Objects for typed fields (enums via `#[ORM\Column(type: 'string', enumType: X::class)]`), Repository interface in `Domain/`, Doctrine implementation in `Infrastructure/` | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` | 🦸 |
| 🗄️ Migrate | Generate migration via `make:migration`, review the SQL manually — never commit a generated migration without reading it first. Verify no data loss on existing tables | `bash: php bin/console make:migration` | — |
| 🧪 Test | Unit tests for domain logic (Value Object validation, entity creation named constructors). Integration tests for repository (use `DAMA\DoctrineTestBundle` with `sqlite:///:memory:` — isolated DB per test, no fixtures bleed) | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | UUID as PK (not auto-increment). All timestamps present (`submittedAt`, `processedAt`). `isSynthetic` flag on every entity. No business logic in entity — data container only. No setters — immutable | `task(subagent="CodeReviewer")` | 🦸 |
| 🗄️ Run | Execute migration against dev DB, verify schema | `bash: php bin/console doctrine:migrations:migrate` | — |
| ✅ Verify | All tests green, migration runs clean forward and back | `skill("verification-before-completion")` | 🦸 |

**Conventions:** `declare(strict_types=1)` in every file. UUID PKs via `UuidGenerator::class`. `#[ORM\Column(type: 'string', enumType: X::class)]` for enums. `isSynthetic` boolean on all entities. `submittedAt` + `processedAt` timestamps on every entity. Named constructors (`::create()`, `::fromArray()`) — no public setters.

**⚠️ Watch out:** Don't use auto-increment IDs (they leak row counts). Don't put business logic in entities (they're data containers). Always review generated migration SQL before committing — Doctrine's diff can produce surprising DDL.

---

## Scenario B2: New API Endpoint

**When:** Adding a new route — REST controller for triage flow or API Platform resource for admin CRUD.
**Success:** Endpoint follows JSON:API conventions, proper HTTP status codes, OpenAPI docs generated, async endpoints return 202.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🧠 Orient | Check existing controllers in the target bounded context, review API conventions (`backend/agents.md` lines 261-323) | `task(subagent="ContextScout")` | 🦸 |
| 📚 Research | If using new packages (API Platform features, symfony/ai response patterns), fetch current docs | `task(subagent="ExternalScout")` | 🦸 |
| 🧠 Align | Define endpoint contract: URL, HTTP method, request body shape, response shape (200/202/422/401). Document in `grill-with-docs` — this becomes the source of truth frontend consumes | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | If the endpoint touches more than 3 files (Command + Handler + DTO + Controller), break down with TaskManager. Otherwise, direct CoderAgent | `skill("writing-plans")` → `task(subagent="TaskManager")` (if >3 files) | 🦸 |
| 🔨 Implement | CQRS flow: `Command`/`Query` (immutable, readonly) → `Handler` (with `#[AsMessageHandler]` or direct DI) → `DTO` (response shape) → `Controller` (manual REST for triage) or `ApiResource` attribute (API Platform for admin). Always constructor injection, never `$container->get()` | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | **Functional** (full request→response cycle, assert JSON structure). **Unit** (handler logic with mocked dependencies). **Validation edge cases** (data providers for empty symptoms, invalid specialist, missing fields). Test both success paths AND error paths. Mock AI platform — never call real DeepSeek | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | HTTP status codes correct (202 for async, 422 for validation, 401/403 for auth). Validation messages specific (field-level errors in JSON:API format). Rate limiting configured on public endpoints. CORS headers present for frontend origin | `task(subagent="CodeReviewer")` | 🦸 |
| 🔭 Context | Verify endpoint doesn't leak data across bounded contexts. Check that route naming matches convention | `skill("zoom-out")` | 🧔 |
| ✅ Verify | Full test suite green. OpenAPI docs generated (`/api/docs`). Manual curl test with valid + invalid payloads. Postman collection updated | `skill("verification-before-completion")` | 🦸 |

**Conventions:** Async endpoints return 202 with `Location` header to status URL. Validation errors → 422 with field-level `errors[]` array. Auth errors → 401 (expired) or 403 (forbidden). Constructor injection only. `readonly` DTOs with named constructors. JSON:API-like `{data: {id, type, attributes}}` response shape.

**⚠️ Watch out:** Never return 200 for errors. Never expose raw AI output through an endpoint — always transform through a DTO. Don't forget rate limiting on the public triage endpoint — it's your most exposed surface.

---

## Scenario B3: New Bounded Context

**When:** Adding a new domain area (e.g., `Billing`, `Notifications`) that deserves its own `src/{Context}/` directory with Application/Domain/Infrastructure layers.
**Success:** Context is fully isolated — own entities, own repository interfaces, communicates with other contexts only via Messenger events.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Discover all existing contexts, their Messenger event contracts, and shared kernel (if any). Understand which events this new context needs to listen to and emit | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define context boundaries, ubiquitous language (write down every term in `CONTEXT.md`), and write an ADR (`docs/adr/YYYY-MM-DD-{context-name}.md`) documenting: why a new context, what it owns, what it emits/listens to, what it NEVER touches | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | Full DDD structure: Value Objects first (no deps) → Entities (depend on VOs) → Repository interfaces (Domain layer) → Domain events → Application Commands/Queries → Handlers → Infrastructure (Doctrine repos, controllers). TaskManager breaks this into dependency-ordered subtasks with parallel batches for independent VOs | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🎫 Issues | Convert the plan into independently-grabbable GitHub issues. One issue per vertical slice so work can be parallelized or handed off | `skill("to-issues")` | 🧔 |
| 🔨 Implement | Build in strict dependency order. Value Objects and Entities first (they have zero deps on other layers). Repository interfaces in Domain. Then Application layer (Commands/Queries/Handlers). Infrastructure last (controllers, Doctrine repo impls). Each batch runs `php bin/phpunit` before proceeding to the next | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🔭 Context | After implementation, zoom out and verify: no entity from another context is imported in this context's Domain. All cross-context communication uses Messenger events. Repository interfaces are in Domain, implementations in Infrastructure | `skill("zoom-out")` | 🧔 |
| 🧪 Test | **Unit** (every Value Object, every domain event). **Integration** (every Doctrine repository with isolated DB). **Functional** (every endpoint). **Messenger integration** (dispatch event, assert handler receives it, assert side effects) | `task(subagent="TestEngineer")` | 🦸 |
| 📝 Document | Update `backend/agents.md` with new context structure. Document new events in a cross-context event catalog. Update `CONTEXT.md` with new domain terms. Generate/update API docs | `task(subagent="DocWriter")` | 🦸 |
| 👁️ Review | Boundary integrity check: grep for cross-context entity imports (they should not exist). No service location (`$container->get()`). All handlers use constructor injection. Events are immutable, readonly classes | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Full suite passes. Messenger consume processes all transports cleanly. No cross-context import violations. ADR committed and referenced in code | `skill("verification-before-completion")` | 🦸 |

**Context rules:** Each context has its own domain model. No cross-context entity references. Communication via Messenger events only. Repo interfaces in Domain, implementations in Infrastructure. Read/Write separation: Queries can bypass domain model; Commands always go through domain.

**⚠️ Watch out:** The most common DDD mistake is importing an entity from another context "just this once." Every cross-context import creates coupling that defeats the purpose of bounded contexts. Use events + a local projection instead. Also: don't create a new context for something that should be a subdirectory of an existing context — a context should represent a distinct business capability, not just a grouping of related files.

---

## Scenario B4: symfony/ai Integration

**When:** Adding a new AI agent (e.g., `specialist_agent` for suggesting specialist types, `summary_agent` for visit summaries) or modifying an existing agent's system prompt.
**Success:** Agent defined in `config/packages/ai.yaml`, system prompt parameterized (never hardcoded), async via Messenger, output validated before use, fallback on malformed AI response.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch current symfony/ai docs — model catalog changes, Agent API updates, response format changes. Also check DeepSeek API docs for model capabilities (`deepseek-chat` vs `deepseek-reasoner` tradeoffs) | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Find all existing AI agents in `config/packages/ai.yaml`, their system prompts, and the services that consume them. Note which use `deepseek-chat` (fast, cheap) vs `deepseek-reasoner` (thoughtful, expensive) | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Design the system prompt: what does this agent do, what JSON schema must it output, what medical constraints apply. Define temperature (0.2-0.3 for medical analysis, 0.7 for synthetic data). Write this into `CONTEXT.md` so frontend and other devs understand what the agent produces | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | **Step 1:** Add agent definition in `ai.yaml` (platform binding, model, system prompt reference, tools: false). **Step 2:** Create system prompt as a service parameter or dedicated class (never inline in yaml). **Step 3:** Build service class following `TriageAnalyzer` pattern — inject `PlatformInterface`, build structured prompt, call `request()`, parse/validate JSON output, return DTO. **Step 4:** Wrap in Messenger handler for async processing. **Step 5:** Configure retry strategy (`messenger.yaml`: max 3 retries, exponential backoff) | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | **Mock `PlatformInterface`** — test valid JSON response maps to correct DTO. **Test malformed response** — AI returns "not json" → expect `TriageAnalysisFailedException`. **Test wrong JSON schema** — AI returns `{"wrong_field": "x"}` → expect validation error. **Test timeout** — mock throws `TimeoutException` → expect retry. **Test retry logic** — first call fails, second succeeds | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Temperature appropriate for use case. System prompt doesn't leak secrets. Output validation is strict (reject anything not matching expected schema). Retry strategy configured (not infinite). AI responses never stored raw in DB without `aiRawResponse` field for debugging | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Agent works in dev. Async flow: submit → 202 → poll → result. Malformed AI output handled gracefully (no 500s). Retry exhausts gracefully (message goes to failure transport, not lost) | `skill("verification-before-completion")` | 🦸 |

**AI rules:** Always async via Messenger (never block HTTP request). Always system prompt with output format constraints. Always validate AI output (parse JSON, check enum values exist). Never expose raw AI output — transform through DTO. Low temperature (0.2-0.3) for medical analysis; higher (0.7) for synthetic data generation. Max 3 retries with exponential backoff.

**⚠️ Watch out:** The AI will occasionally return malformed JSON or miss required fields. If you don't validate strictly, a typo in the AI output becomes a 500 error for the user. Always wrap AI calls in try/catch with a specific fallback. Never use `tools: true` unless you've explicitly designed tool-calling agents — it introduces complexity that's hard to test.

---

## Scenario B5: Doctrine Migration

**When:** Schema changed — new entity, column added, column type modified, or index added.
**Success:** Migration generated, manually reviewed, tested in isolated DB, runs forward and backward cleanly.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Check current schema vs entity mapping. Identify exactly what changed: new entities, new columns on existing tables, type changes (risky!), removed columns | `bash: php bin/console doctrine:schema:update --dump-sql` | — |
| 🔨 Generate | Let Doctrine diff the current mapping against the DB and generate a migration class | `bash: php bin/console make:migration` | — |
| 🔨 Review | **This is the most important step.** Open the generated migration file. Read every SQL statement. Ask: is there data loss (`DROP COLUMN`, `DROP TABLE`)? Are column types correct? Are there default values for new NOT NULL columns on existing tables? Add `-- rollback` SQL comments for each `up()` statement if Doctrine doesn't generate them automatically | Manual (read the migration file in `migrations/Version*.php`) | — |
| 🧪 Test | Run integration tests with the new schema. `DAMA\DoctrineTestBundle` creates a fresh in-memory SQLite DB per test — this catches schema mismatches. Run: `php bin/phpunit --filter=Integration` | `bash: php bin/phpunit --filter=Integration` | — |
| 🔨 Migrate | Run migration against dev DB | `bash: php bin/console doctrine:migrations:migrate` | — |
| 🔨 Rollback | Test rollback: migrate down, verify schema returns to previous state | `bash: php bin/console doctrine:migrations:migrate prev` | — |
| ✅ Verify | Migration runs on dev. Integration tests pass. Rollback works. No irreversible operations in migration (unless explicitly documented) | `skill("verification-before-completion")` | 🦸 |

**Rules:** Always review generated SQL before committing. Never modify an existing migration — create a new one. Test with `sqlite:///:memory:` in test env. Add rollback comments. Never use `schema:update --force` in production (always use migrations).

**⚠️ Watch out:** Doctrine's diff can generate `DROP TABLE` + `CREATE TABLE` instead of `ALTER TABLE`. If you see `DROP` in a migration on a table with data, stop — manually rewrite as `ALTER`. Also: running `make:migration` when another developer's unmerged migration exists will produce a migration that conflicts. Always pull/merge before generating migrations.

---

## Scenario B6: Async Queue / Messenger

**When:** Adding async processing — new message type, new handler, new transport, or modifying retry/failure behavior.
**Success:** Message dispatched, handler processes asynchronously, retry works on failure, exhausted messages go to failure transport (not lost).

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find existing message classes (they define the contract), handlers (they define the behavior), and transport config in `messenger.yaml`. Understand which transport handles what: `async` (AI calls), `scheduler_default` (cron tasks), `failed` (dead letter queue) | `task(subagent="ContextScout")` | 🦸 |
| 🔨 Implement | **Message class:** Plain PHP object, `readonly`, holds data the handler needs. **Handler:** Class with `#[AsMessageHandler]` attribute (or `__invoke()` with message type hint). **Transport routing:** Configure in `messenger.yaml` — route message class to correct transport. **Retry strategy:** Per-transport or per-message: `max_retries: 3`, `delay: 1000` (1s), `multiplier: 2` (exponential backoff: 1s, 2s, 4s) | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | **Unit:** Handler processes message correctly (mock dependencies). **Integration:** Dispatch message via `MessageBusInterface`, assert handler was called (use `MessengerTestCase` or manually consume in test). **Retry test:** Throw exception in handler, assert message is retried. **Failure test:** Assert message lands in failure transport after exhausting retries | `task(subagent="TestEngineer")` | 🦸 |
| 🔭 Context | Verify message flows don't create cycles (Context A emits → Context B handles → Context B emits → Context A handles → infinite loop). Check that message payloads don't contain entities (they should contain IDs, not objects) | `skill("zoom-out")` | 🧔 |
| 👁️ Review | Retry strategy configured (not infinite). Failure transport exists and is consumed/monitored. Message classes are serializable (no closures, no resources). Handler doesn't have side effects that are unsafe to retry (idempotency!) | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | `messenger:consume async` processes messages. Retry triggers on failure. Failed messages appear in `messenger:failed:show`. Can retry failed messages with `messenger:failed:retry` | `skill("verification-before-completion")` | 🦸 |

**Transports:** `async` (AI calls + general async work), `scheduler_default` (cron-triggered synthetic case generation), `failed` (dead letter queue — messages that exhausted all retries).

**⚠️ Watch out:** Handlers must be idempotent — Messenger may deliver a message more than once. If your handler sends an email or creates a DB row, design it so running twice doesn't double-send or double-create. Also: message payloads must be serializable. Don't put Doctrine entities in messages (they won't deserialize correctly after the entity manager is cleared).

---

## Scenario B7: API Contract Change (affects frontend)

**When:** Modifying an endpoint's response shape, adding/removing fields, or changing field types — anything the frontend depends on.
**Success:** Change is backward-compatible (or versioned), frontend API types updated, OpenAPI docs regenerated, no frontend breakage.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find all endpoints using the affected DTO/entity. Check OpenAPI annotations for each. Find all frontend files that consume these types (`frontend/src/api/types.ts` and all TanStack Query hooks in `api/hooks.ts`) | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Decide: additive change (add field — backward compatible) or breaking change (remove/rename field — needs versioning or coordinated deploy). Coordinate with frontend: what does the new field mean, how should it be displayed, what's the fallback if it's `null` | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | **Additive:** Add field to DTO/entity, add to OpenAPI annotation, mark as `nullable` if old records won't have it. **Breaking:** Add new field, mark old field as `@deprecated` in OpenAPI, keep old field returning data for one deploy cycle, then remove in next deploy once frontend has migrated | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | **Backward compatibility test:** Old frontend code (current production) should still parse new response without errors. **New field test:** New field present with correct type and data. **Null field test:** Record created before migration — new field should be `null`, not crash | `task(subagent="TestEngineer")` | 🦸 |
| 📝 Document | Update frontend API types (`api/types.ts`). Update TanStack Query hooks if response shape changed. Add a note in the handoff for the frontend dev (or yourself switching hats) | `task(subagent="DocWriter")` | 🦸 |
| 👁️ Review | Deprecation strategy is clear. Old fields have a removal timeline. No silent type changes (e.g., `string` → `int` — that's breaking). New fields have sensible defaults for old records | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Old frontend works against new backend. New frontend works with old backend (if possible). OpenAPI docs reflect the change. No 500s for records in any state | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** The most painful contract breaks are silent — changing a field from optional to required, or changing `string` to `number`. The frontend TypeScript types will be wrong and you'll get runtime errors, not compile errors. Always test with real API responses, not just mock data.

---

## Scenario B8: Backend Debugging

**When:** Test failure, 500 error, slow query, unexpected AI output, or "it worked yesterday."
**Success:** Root cause found, fix applied with test proving it, no regression.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🐛 Reproduce | Isolate the failure. Write a failing test that captures the exact conditions. For API bugs: capture curl command + payload. For query bugs: capture the SQL that's slow/wrong. For AI bugs: capture the exact input + malformed output | Manual + `bash: php bin/phpunit --filter=FailingTest` | — |
| 🔍 Diagnose | Use `systematic-debugging` to eliminate possibilities: is it a code bug, a config issue, an environment problem, a data problem? Check Symfony profiler (`/_profiler` → last request) for: DB queries, exceptions, request/response, performance timeline | `skill("systematic-debugging")` | 🦸 |
| 🔎 Explore | Find all code paths related to the failure. grep for callers of the broken method. Check if the bug is in the handler, the repository, an event listener, or middleware | `task(subagent="explore")` (quick → very thorough as needed) | 🦸 |
| 🔭 Context | Understand how the broken code fits into the bounded context. Could this bug affect other contexts? Is there a contract being violated? | `skill("zoom-out")` | 🧔 |
| 🔨 Fix | Write the failing test first (it should fail, proving you captured the bug). Then implement the fix. Run the single test → green. Run the full suite → still green. If the fix changes behavior, update any tests that relied on the old (buggy) behavior | `skill("tdd-workflow")` | 🦸 |
| 👁️ Review | Fix is minimal (changed only what's needed). No new edge cases introduced. Error handling improved (bug showed a gap — close it) | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Original bug is gone. Full test suite passes. No new deprecation warnings. Profiler shows no N+1 queries introduced by the fix | `skill("verification-before-completion")` | 🦸 |

**Debug tools:** Symfony Profiler (`/_profiler` → last 10 requests). `php bin/console debug:router` (route listing). `php bin/console debug:autowiring {class}` (DI inspection). `php bin/console doctrine:query:sql "SELECT ..."` (raw SQL test). `php bin/console messenger:failed:show` (failed messages).

**⚠️ Watch out:** Don't fix the symptom (e.g., catch the exception and return null). Fix the root cause. If a method returns `null` unexpectedly, don't add a null check — find out why it returned null. Also: after fixing, check if the same bug pattern exists elsewhere in the codebase.

---

## Scenario B9: Authentication & Authorization

**When:** Adding login/logout, protecting new endpoints with JWT, implementing role-based access (voters), or configuring CORS for new origins.
**Success:** JWT issued on login, validated on every request, voters enforce business rules, rate limiting protects public endpoints.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch current `lexik/jwt-authentication-bundle` docs (token creation, refresh, revocation patterns) and Symfony security component docs (voters, access control, firewall config) | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Check existing security config (`config/packages/security.yaml`), voter classes, JWT configuration, and CORS settings. Note which routes are public vs protected vs admin-only | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define access rules: what roles exist (ROLE_USER, ROLE_ADMIN), which endpoints require which roles, what's fully public | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | **JWT config:** `lexik_jwt_authentication.yaml` — token TTL, refresh TTL, user identity provider. **Firewall:** `security.yaml` — `pattern: ^/api`, stateless, JWT authenticator. **Access control:** `access_control` rules for public vs protected paths. **Voters:** Custom voter class implementing `VoterInterface` — `supports()`, `voteOnAttribute()`. Inject voter, call `$this->denyAccessUnlessGranted()` in controller or `#[IsGranted]` attribute. **CORS:** `nelmio_cors.yaml` — allow frontend origin, allow Authorization header | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | **Unauthenticated access:** assert 401 on protected endpoint. **Wrong role:** assert 403 for user without required role. **Expired token:** assert 401 (not 500). **Valid access:** assert 200 with correct JWT. **Voter logic:** test each permission scenario (owner can edit own submission, admin can edit all, etc.) | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Token secrets in `.env.local` (never committed). Rate limiting on public endpoints. No hardcoded roles in controller logic (use voters). CORS limited to specific origin (not `*`) | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Login returns JWT. Protected endpoint rejects without token. Voter allows/denies correctly. CORS headers present for frontend. Rate limit triggers after threshold | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** JWT tokens are stateless — you can't revoke them server-side without a blacklist. Keep TTL short (15-30 min) and use refresh tokens for longer sessions. Never store JWT secrets in config files committed to git. Test with actually expired tokens (not just missing tokens) — expired tokens should return 401, not 500.

---

## Scenario B10: Validation & Error Handling

**When:** Adding validation rules to a DTO, improving error response format, or handling a new exception type consistently across all endpoints.
**Success:** Invalid input → 422 with field-specific errors in JSON:API format. Exceptions mapped to correct HTTP status. No raw exception traces in production responses.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find existing DTOs, their validation constraints, the exception mapping (check `config/packages/framework.yaml` error handling), and the JSON:API error response format | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define validation rules per field. Define error response structure: `{"errors": [{"status": "422", "code": "VALIDATION_FAILED", "title": "...", "detail": "...", "source": {"pointer": "/data/attributes/{field}"}}]}` | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | **DTO validation:** `#[Assert\NotBlank]`, `#[Assert\Count(min: 1)]`, `#[Assert\All([new Assert\Choice(...)])]` etc. on DTO properties. **Controller:** Inject `ValidatorInterface`, call `$validator->validate($dto)`, if violations → throw custom `ValidationFailedException` with violations array. **Exception mapping:** Event listener on `kernel.exception` — maps `ValidationFailedException` → 422 JSON response, `AccessDeniedException` → 403, `AuthenticationException` → 401, everything else → 500 (with generic message in production) | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Test every validation rule: missing required field → 422 with field pointer. Wrong enum value → 422 with allowed values in detail. Valid payload → 200. Test exception mapping: throw each exception type, assert correct HTTP status and JSON structure | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Validation messages are user-friendly (not "Field 'symptoms' is not valid" — say "At least one symptom is required"). No exception traces in JSON responses. All error responses follow the same JSON:API structure | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Every validation rule triggers correct error. Exception responses are consistent across all endpoints. Production error responses don't leak stack traces | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** Symfony's default exception controller renders HTML even for API routes. You need a JSON exception listener for API paths (`/api/*`). Also: don't put validation logic in controllers — put it on the DTO with attributes, validate in the controller or a listener. Controllers should be thin.

---

## Scenario B11: Testing Strategy

**When:** Setting up testing for a new feature, improving coverage, or deciding test types for a given code path.
**Success:** Clear test pyramid: lots of fast unit tests, moderate integration tests, few but critical functional tests. 80%+ coverage without testing getters. AI calls always mocked.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Check current `phpunit.xml.dist` config, existing test patterns, DAMA bundle setup, and coverage report (`php bin/phpunit --coverage-html var/coverage`) | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Decide test pyramid for this feature: what's unit (fast, no DB/AI), what's integration (DB with DAMA, Messenger with real transport in test), what's functional (full HTTP request→response) | `skill("grill-with-docs")` | 🧔 |
| 🔨 Write | **Unit tests:** Test every Value Object, every domain event, every handler with mocked deps. **Integration tests:** Test every Doctrine repository with `DAMA\DoctrineTestBundle` (fresh SQLite per test). Test Messenger handlers end-to-end in test transport. **Functional tests:** Test every endpoint — valid payload, invalid payload, auth scenarios. **AI mocking:** Always mock `PlatformInterface` — use `->willReturn()` with known JSON responses. Include malformed response test cases | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Coverage ≥80%. Tests cover error paths (not just happy path). Data providers used for validation edge cases. No tests depend on execution order. CI runs full suite | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Tests pass locally. Tests pass in CI. Coverage report shows no uncovered critical paths. No skipped or incomplete tests | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** The most common testing mistake in Symfony is testing with a real database that accumulates state. Use `DAMA\DoctrineTestBundle` — it creates a fresh in-memory SQLite for every test. Also: never call the real DeepSeek API in tests. It's slow, costs money, and is non-deterministic. Always mock `PlatformInterface`.

---

## Scenario B12: CI/CD Pipeline

**When:** Setting up GitHub Actions for automated linting, static analysis, testing, and deploy readiness checks.
**Success:** Every push triggers: PHP CS Fixer → PHPStan (level 8+) → PHPUnit (full suite) → coverage check. PRs can't merge if CI is red.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch current GitHub Actions docs for PHP setup, caching strategies (composer cache), and Symfony-specific CI best practices | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Check if `.github/workflows/` already exists, what PHP version matrix is needed, what services (PostgreSQL, Redis) are needed for tests | `task(subagent="ContextScout")` | 🦸 |
| 🔨 Implement | Create `.github/workflows/ci.yml`: **Lint job:** `php-cs-fixer fix --dry-run --diff`. **Static analysis job:** `phpstan analyse --level=8` (level 8 = strictest, no `mixed` types). **Test job:** Setup PHP 8.4 + PostgreSQL service + `composer install` + `php bin/phpunit --coverage-text`. **Coverage check:** Fail if <80%. Cache `vendor/` and composer downloads for speed. Run on push to any branch + PR to `main` | `task(subagent="CoderAgent")` → `task(subagent="OpenDevopsSpecialist")` | 🦸 |
| 👁️ Review | Pipeline completes in <5 min. Caching works (subsequent runs are fast). Secrets (API keys) not exposed in logs. Coverage gate enforced | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Push triggers CI. All jobs pass. Intentional failure (break a test) → CI goes red. PR view shows CI status. Coverage report visible in CI output | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** CI databases need to match production as closely as possible. If you use PostgreSQL in production, don't test with SQLite in CI (use a PostgreSQL service container). PHPStan level 8 is strict — you may need to add type hints throughout the codebase before enabling it. Start at level 5 and incrementally raise it.

---

## Scenario B13: Performance Optimization

**When:** Slow endpoint, N+1 query problem, high response time on triage submission, or Messenger worker falling behind.
**Success:** Queries are optimized (no N+1), caching is used where appropriate, async work is batched, profiling confirms improvements.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Profile | Identify bottlenecks: Symfony Profiler → Performance tab → query count + time. Check for N+1: does one request trigger dozens of similar queries? Check Messenger: are messages piling up? (`messenger:failed:show`) | Manual + Symfony Profiler | — |
| 🔎 Explore | Find the responsible code: which repository method triggers N+1? Which handler is slow? Which query lacks an index? | `task(subagent="explore")` | 🦸 |
| 🔨 Fix | **N+1 fix:** Add `fetch: 'EAGER'` or use Doctrine `JOIN` in custom repository method (`createQueryBuilder` with `leftJoin` + `addSelect`). **Slow query fix:** Add database index (`#[ORM\Index]` on frequently queried columns), use partial selects (only fetch needed fields). **Messenger batch:** If handler processes one item at a time, batch them. **Cache:** Use Symfony Cache component for expensive computations that don't change often | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Verify | Before/after profiler comparison: query count decreased, response time improved. Test still pass. No regression in behavior | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** Eager loading everything is as bad as N+1 (you load data you don't need). Be surgical: only `JOIN`/`EAGER` the relations you know you'll use. Use the Profiler to see exactly which queries fire. Also: don't cache data that changes frequently — stale cache is worse than a slightly slow query.

---

## Backend Quick Reference

```
New entity?           → context-scout → grill-with-docs → coder → make:migration → test-engineer → review → verify
New endpoint?         → context-scout → external-scout → grill-with-docs → (plan if >3 files) → tdd → test-engineer → review → zoom-out → verify
New bounded context?  → context-scout → grill-with-docs → write-plan → to-issues → tdd (batches) → zoom-out → tests → doc-writer → review → verify
symfony/ai?           → external-scout → context-scout → grill-with-docs → tdd → test-engineer → review → verify
Doctrine migration?   → schema:update --dump-sql → make:migration → review → migrate → test → rollback → verify
Async queue?          → context-scout → coder → test-engineer → zoom-out → review → verify
API contract change?  → context-scout → grill-with-docs → coder → tests → doc-writer → review → verify
Debugging?            → systematic-debugging → explore → zoom-out → tdd → review → verify
Auth/security?        → external-scout → context-scout → grill-with-docs → coder → test-engineer → review → verify
Validation/errors?    → context-scout → grill-with-docs → coder → test-engineer → review → verify
Testing strategy?     → context-scout → grill-with-docs → test-engineer → review → verify
CI/CD?                → external-scout → context-scout → coder → devops-specialist → review → verify
Performance?          → profile (profiler) → explore → coder → verify (before/after profiler comparison)
```

**Cross-reference:** Frontend scenarios → [`tools-scenarios-frontend.md`](tools-scenarios-frontend.md) | Master reference → [`tools-scenarios-matrix.md`](tools-scenarios-matrix.md)
