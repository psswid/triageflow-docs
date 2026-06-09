# Handoff: Issue #3 — Triage Interview Pipeline

**Date**: 2026-05-30
**Session**: Triage Interview implementation (all 5 batches)
**Status**: COMPLETE — committed and pushed

## What Was Built

Full AI-powered medical triage interview pipeline across backend (Symfony 7.4) and frontend (React 19 + TanStack Query v5).

### Backend (36 files, 4,602 lines)

**Domain layer** (`src/Triage/Domain/`):
- `TriageStatus` — PHP 8.4 string-backed enum (Pending, Processing, AwaitingAnswer, Completed, Failed)
- `TriageOutcome` — Doctrine Embeddable value object (specialist, urgency, justification), nullable on parent entity
- `TriageSubmission` — Aggregate root: UUID PK, ManyToOne→User, json conversationHistory column (`{type, content, timestamp}` entries, no `role` field), Embedded TriageOutcome, currentTurn int (starts 0, increments on AI question)
- `TriageSubmissionRepository` interface → `DoctrineTriageSubmissionRepository`

**AI layer** (`src/Shared/Infrastructure/Ai/`, `src/Triage/Application/Service/`):
- `OpenRouterClient` (wraps `symfony/http-client`) + `OpenRouterClientInterface` (extracted for test mocking)
- `TriageSystemPrompt` — full system prompt with specialist list, JSON output format, character limits
- `TriageAnalyzer` — JSON discrimination (question vs result), turn-3 force-result, malformed JSON fallback → `TriageAnalyzerInterface`

**Pipeline** (`src/Triage/Application/`):
- `SubmitTriageCommand` + `SubmitTriageHandler` — initial submission flow
- `ProcessTriageMessage` + `ProcessTriageMessageHandler` — async Messenger handler for follow-up processing
- Messenger routing configured in `config/packages/messenger.yaml`

**Controllers** (`src/Triage/Infrastructure/Controller/`):
- 5 endpoints: POST submit, POST answer, GET status (lightweight poll), GET result (nested `outcome` object), GET submissions (deferred, returns `[]`)
- Ownership checks (403 if user mismatch)
- `config/routes/triage.yaml` — attribute-based routing

**Test double**: `TestTriageAnalyzer` + `config/services_test.yaml` for functional tests.

### Frontend (15 files, 1,964 lines)

- **TypeScript types**: Updated `api/types.ts` — 5-state status machine, `TriageOutcome` type, dropped `role` from ConversationMessage (type encodes sender)
- **Hooks**: `useTriagePolling` (TanStack Query refetchInterval), `useTriageInterview` (6-state machine: idle→submitting→polling→awaiting_answer→completed/failed)
- **Pages**: `TriagePage` (initial symptom → conversation → answer input → redirect to result), `TriageResultPage` (OutcomeCard + UrgencyBadge + conversation history)
- **Components**: `ConversationBubble`, `SymptomInput`, `AnswerInput`, `UrgencyBadge`, `OutcomeCard`

### Test Coverage
- **Backend**: 170 tests, 509 assertions (PHPUnit)
- **Frontend**: 41 tests (vitest), TSC clean, ESLint clean

## Key Design Decisions (from grill-with-docs)

See commit messages and `CONTEXT.md` for full glossary. Key points:
- Single-entity design: `TriageSubmission` contains everything, `TriageOutcome` is an Embeddable (not separate entity) — ADR-0004
- Conversation history as JSON column (not normalized turns table) — ADR-0005
- Turn counting: `currentTurn` starts at 0, increments on AI question, force-result at turn ≥ 3
- JSON discrimination: `{"type":"question"}` vs `{"type":"result","specialist":"...","urgency":"...","justification":"..."}`
- No enum for specialists/urgency — string-based, TriageSystemPrompt defines the list
- Async via Symfony Messenger, 3 retries, failed transport configured

## Commits

| Repo | SHA | Message |
|------|-----|---------|
| docs | `58b7f59` | `docs: add TriageOutcome term to domain glossary` |
| backend | `d93f4aa` | `feat(triage): implement AI-powered triage interview pipeline` |
| backend | `b589cb6` | `🔒️ fix: untrack .env.dev from git (already gitignored)` |
| frontend | `445ad94` | `feat(triage): implement interview UI with polling and result display` |

## ADRs Created

- `docs/adr/0004-single-aggregate-embedded-outcome.md` — TriageOutcome as Doctrine Embeddable, not separate entity
- `docs/adr/0005-json-column-conversation-history.md` — Conversation history in JSON column, not normalized turns table

## Deferred / Known Gaps

- **MySubmissionsPage** — deferred to later issue (endpoint stubbed, returns `[]`)
- **Processing duration** — `processingDuration` field in TypeScript types, not yet computed in backend
- **Fallback model** — configured in services.yaml but never used in retry logic
- **Integration/E2E tests** — no API contract tests between frontend and backend response shapes
- **Rate limiting** — no rate limits on submit/answer/status endpoints (acceptable for demo)
- **Prompt injection** — LLM jailbreak risk is inherent to the architecture, documented but not mitigated

## Security Review (2026-05-30)

### Passed ✅
- Ownership enforced (403 if user_id mismatch)
- Input validated at 3 layers (controller/entity/frontend)
- No raw SQL (Doctrine ORM only)
- No secrets in committed code (API keys via env vars)
- Stateless JWT with expiry
- Route-level access control (ROLE_USER)
- `config/jwt/*.pem` gitignored
- `.env.local` gitignored + untracked

### Flagged ⚠️
- **Prompt injection**: User input flows directly to LLM without sanitization. Inherent LLM limitation, acceptable for demo.
- **JWT in localStorage**: Vulnerable to XSS token theft. Acceptable for demo.
- **Error detail leakage**: Validation errors expose field names (`initialDescription`). Acceptable for demo.

### Fixed 🔒️
- `b589cb6` — untracked `.env.dev` (was committed before gitignore rule added)
- `OPENROUTER_API_KEY` never committed (empty placeholder in `.env`, real key in `.env.local`)

## Suggested Skills for Next Session

- `brainstorming` — before implementing new features
- `grill-with-docs` — stress-test plans against domain model + CONTEXT.md
- `writing-plans` — for multi-step feature breakdown
- `to-issues` — break plans into independently-grabbable issues
- `tdd-workflow` — mandatory test-first development
- `requesting-code-review` — after each major feature
- `verification-before-completion` — evidence before claims
- `finishing-a-development-branch` — when ready to merge
