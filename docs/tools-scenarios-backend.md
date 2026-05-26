# TriageFlow — Backend Scenarios

> Symfony 7.4 + Doctrine + symfony/ai + DDD Light — every backend scenario, every tool, every gate.
> Load `backend/agents.md` before any backend work.
> Origin tags: 🦸 Superpowers | 🧔 Matt Pocock | 🏠 Project (triageflow)

---

## Scenario B1: New Entity + Repository

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🧠 Orient | Load backend/agents.md, find existing DDD patterns | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define entity domain language, add to CONTEXT.md | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | Entity (PHP 8.4, `final`, `readonly`, `#[ORM\]` attrs), Repository interface + Doctrine impl | `task(subagent="CoderAgent")` | 🦸 |
| 🗄️ Migrate | Generate + review migration | `bash: php bin/console make:migration` | — |
| 🧪 Test | Unit (domain logic) + Integration (Doctrine, isolated DB via `DAMA\DoctrineTestBundle`) | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Entity correctness, UUID, enums, isSynthetic flag | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Tests pass, migration clean | `skill("verification-before-completion")` | 🦸 |

**Conventions:** `declare(strict_types=1)`, UUID PKs, `#[ORM\Column(type: 'string', enumType: X::class)]`, `isSynthetic` flag, `submittedAt` + `processedAt` timestamps.

---

## Scenario B2: New API Endpoint

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🧠 Orient | Check existing controllers, API conventions (JSON:API-like) | `task(subagent="ContextScout")` | 🦸 |
| 📚 Research | Fetch symfony/ai or API Platform docs if new package used | `task(subagent="ExternalScout")` | 🦸 |
| 🧠 Align | Define endpoint contract (URL, method, request/response shapes) | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | If >3 files: Command, Handler, DTO, Controller | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🔨 Implement | CQRS: Command/Query → Handler → DTO → Controller (manual REST) or ApiResource (API Platform) | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Functional (full request/response cycle) + Unit (handler logic) + Validation edge cases | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | HTTP status correctness, validation, security (JWT + rate limit) | `task(subagent="CodeReviewer")` | 🦸 |
| 🔭 Context | See how endpoint fits bounded context boundaries | `skill("zoom-out")` | 🧔 |
| ✅ Verify | All tests green, OpenAPI docs generated | `skill("verification-before-completion")` | 🦸 |

**Conventions:** Async endpoints return 202 + status URL. Validation errors → 422. Auth errors → 401/403. Constructor injection only. `readonly` DTOs.

---

## Scenario B3: New Bounded Context

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Discover existing contexts, coupling, Messenger event contracts | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define context boundaries, domain language, write ADR | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | Full DDD structure: Application/ Domain/ Infrastructure/ — dependency order, parallel batches | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🎫 Issues | Plan → GitHub issues (one per vertical slice) | `skill("to-issues")` | 🧔 |
| 🔨 Implement | Build in dependency order: Value Objects → Entities → Repository interface → Doctrine repo → Handlers → Controller | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🔭 Context | Verify context boundaries intact, no cross-context entity refs | `skill("zoom-out")` | 🧔 |
| 🧪 Test | Unit (domain), Integration (repos), Functional (endpoints) | `task(subagent="TestEngineer")` | 🦸 |
| 📝 Document | Update agents.md, patterns, cross-context event catalog | `task(subagent="DocWriter")` | 🦸 |
| 👁️ Review | Boundary integrity, no service location, DDD rules | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Full suite passes, Messenger events fire correctly | `skill("verification-before-completion")` | 🦸 |

**Context rules:** Each context has own domain model. No cross-context entity references. Communication via Messenger events only. Repo interfaces in Domain, implementations in Infrastructure.

---

## Scenario B4: symfony/ai Integration

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch current symfony/ai docs (model config, Agent API) | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Find existing AI agents, system prompts, async patterns | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define new Agent, system prompt content, output format (JSON schema) | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | `config/packages/ai.yaml` Agent definition → System prompt parameter → `TriageAnalyzer`-style service → Messenger handler for async | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Mock `PlatformInterface`, test valid + malformed AI responses, fallback paths | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Temperature (0.2-0.3 medical, 0.7 synthetic), retry strategy, output validation | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Agent works, async flow correct, error fallback handles malformed output | `skill("verification-before-completion")` | 🦸 |

**AI rules:** Always async via Messenger. Always system prompt. Always validate AI output (parse JSON, check enum values). Never expose raw AI output. Low temp for analysis, higher for generation.

---

## Scenario B5: Doctrine Migration

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find entity changes (new entities, modified columns, embedded changes) | `bash: php bin/console doctrine:schema:update --dump-sql` | — |
| 🔨 Generate | Generate migration | `bash: php bin/console make:migration` | — |
| 🔨 Review | Read generated migration, verify SQL, add rollback comment | Manual (read the migration file) | — |
| 🧪 Test | Integration tests pass with new schema (DAMA\DoctrineTestBundle resets per test) | `bash: php bin/phpunit --filter=Integration` | — |
| ✅ Verify | Migration runs clean, no data loss, rollback possible | `skill("verification-before-completion")` | 🦸 |

**Rules:** Always review generated SQL before committing. Never modify an existing migration — create new one. Test with `sqlite:///:memory:` in test env.

---

## Scenario B6: Async Queue / Messenger

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find existing message classes, handlers, transport config | `task(subagent="ContextScout")` | 🦸 |
| 🔨 Implement | Message class → Handler (with `#[AsMessageHandler]`) → Retry config in `messenger.yaml` | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Dispatch message, assert handler called, test retry on failure | `task(subagent="TestEngineer")` | 🦸 |
| 🔭 Context | Verify message flows match bounded context boundaries | `skill("zoom-out")` | 🧔 |
| 👁️ Review | Retry strategy (max 3 for AI calls), failure transport, DLQ | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | `messenger:consume` processes, retries work, failed messages go to failure transport | `skill("verification-before-completion")` | 🦸 |

**Transports:** `async` (AI calls), `scheduler_default` (synthetic case gen), `failed` (DLQ).

---

## Scenario B7: API Contract Change (affects frontend)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find all endpoints using the contract, all OpenAPI annotations | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Coordinate with frontend (check frontend/agents.md, API types) | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | Add new field/endpoint, mark old as deprecated, update OpenAPI | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Backward-compatible functional tests, new endpoints tested | `task(subagent="TestEngineer")` | 🦸 |
| 📝 Document | Update frontend API types, notify frontend team (or self if solo) | `task(subagent="DocWriter")` | 🦸 |
| 👁️ Review | Deprecation strategy, breakage risk, versioning | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Old responses still work, new fields present, no 500s | `skill("verification-before-completion")` | 🦸 |

---

## Scenario B8: Backend Debugging

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🐛 Reproduce | Isolate failure (query, endpoint, AI call) | Manual + `bash: php bin/phpunit --filter=FailingTest` | — |
| 🔍 Diagnose | Root cause analysis | `skill("systematic-debugging")` | 🦸 |
| 🔎 Explore | Find related code paths (callers, services, middleware) | `task(subagent="explore")` (quick → very thorough) | 🦸 |
| 🔭 Context | Understand affected area in bounded context | `skill("zoom-out")` | 🧔 |
| 🔨 Fix | Red → green → refactor | `skill("tdd-workflow")` | 🦸 |
| 👁️ Review | Fix correctness, no regression | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Bug gone, full suite passes | `skill("verification-before-completion")` | 🦸 |

**Debug tools:** Symfony Profiler (`/_profiler`), `php bin/console debug:router`, `php bin/console doctrine:query:sql`.

---

## Backend Quick Reference

```
New entity?           → context-scout → grill-with-docs → coder → make:migration → test-engineer → review → verify
New endpoint?         → context-scout → external-scout → grill-with-docs → (plan if >3 files) → tdd → test-engineer → review → zoom-out → verify
New bounded context?  → context-scout → grill-with-docs → write-plan → to-issues → tdd (batches) → zoom-out → tests → doc-writer → review → verify
symfony/ai?           → external-scout → context-scout → grill-with-docs → tdd → test-engineer → review → verify
Doctrine migration?   → schema:update --dump-sql → make:migration → review → test → verify
Async queue?          → context-scout → coder → test-engineer → zoom-out → review → verify
API contract change?  → context-scout → grill-with-docs → coder → tests → doc-writer → review → verify
Debugging?            → systematic-debugging → explore → zoom-out → tdd → review → verify
```

**Cross-reference:** Frontend scenarios → `docs/tools-scenarios-frontend.md` | Master reference → `docs/tools-scenarios-matrix.md`
