# TriageFlow Phase 1 — Implementation Handoff

> Session: 2026-05-28 | Pipeline completed: ALIGN → PLAN → ISSUES
> Next: 🔨 IMPLEMENT (pick up issue #1)

## What Was Decided

Full domain glossary established — see `CONTEXT.md`. Key architecture: Symfony 7.4 + React 19, DDD Light (3 bounded contexts), OpenRouter free models for app traffic, AI-driven chat interview (max 3 turns), JWT auth, polling for async results.

See `docs/adr/0001-openrouter-free-models.md` for the AI provider decision.

## Artifacts (reference — do NOT duplicate)

| Artifact | Location |
|----------|----------|
| Domain glossary | `CONTEXT.md` |
| AI provider ADR | `docs/adr/0001-openrouter-free-models.md` |
| Backend plan (19 tasks) | `docs/superpowers/plans/2026-05-28-backend-foundation.md` |
| Frontend plan (11 tasks) | `docs/superpowers/plans/2026-05-28-frontend-foundation.md` |
| GitHub issues (#1-#7) | https://github.com/psswid/triageflow-docs/issues |
| Master agent config | `agents.md` |
| Backend conventions | `backend/agents.md` |
| Frontend conventions | `frontend/agents.md` |

## GitHub Issue Dependency Chain

```
#1 Project Scaffolding
 └─ #2 User Authentication
      └─ #3 Triage Interview
           ├─ #4 Admin Dashboard
           └─ #5 Synthetic Case Generator
                └─ #6 Admin Tools
                     └─ #7 Testing & Polish
```

Issues #4 and #5 are parallel (both depend on #3, no dependency between them).

## Next Session: Issue #1 — Project Scaffolding

Start with GitHub issue: https://github.com/psswid/triageflow-docs/issues/1

The issue has a "Before starting" section listing Context7 doc fetches needed. **Critical: always fetch current docs for Symfony, React, Tailwind, etc. before coding — training data is outdated.**

### Suggested skills for the session

```
skill("using-git-worktrees")        # Isolate work if not already in worktree
skill("tdd-workflow")               # Enforce TDD for all code
skill("context7")                   # Fetch current Symfony/React/Tailwind docs
skill("subagent-driven-development") # Execute plan tasks
skill("verification-before-completion")  # Verify before claiming done
```

### Quick reference

```bash
# Backend
cd backend && docker compose up -d --build
cd backend && docker compose run --rm php bin/console doctrine:database:create

# Frontend
cd frontend && npm run dev

# Verify
cd backend && docker compose run --rm php vendor/bin/phpunit
cd frontend && npm run test -- --run
```

### Pre-session checklist

- [ ] Load `CONTEXT.md` for domain language
- [ ] Load `agents.md` for project conventions
- [ ] Load `backend/agents.md` before touching backend code
- [ ] Load `frontend/agents.md` before touching frontend code
- [ ] Fetch current framework docs via Context7 (Symfony 7.4, React 19, Tailwind CSS 4, etc.)
- [ ] Read GitHub issue #1 acceptance criteria
- [ ] Read implementation plans Tasks 1-3 (backend) and Tasks 1-3 (frontend)
