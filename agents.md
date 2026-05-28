# TriageFlow — AI Agent Configuration

> Master agent guide for TriageFlow: AI-assisted patient triage showcase built with Symfony 7.4 + React + symfony/ai. This file governs how AI agents (OpenCode + Subagents) operate across the entire project.

## Quick Reference

```bash
# Start backend dev server
cd backend && symfony server:start

# Start frontend dev server
cd frontend && npm run dev

# Run backend tests
cd backend && php bin/phpunit

# Run frontend tests
cd frontend && npm run test

# Generate synthetic case (manual trigger)
cd backend && php bin/console app:synthetic-case:generate

# Run scheduler (auto-generate every 60s)
cd backend && php bin/console messenger:consume scheduler_default
```

**Key URLs:**
- Backend API: `http://localhost:8000/api`
- OpenAPI docs: `http://localhost:8000/api/docs`
- Frontend: `http://localhost:5173`
- Symfony AI docs: https://symfony.com/doc/current/ai/index.html

## Project Overview

**TriageFlow** is a 2-week portfolio project demonstrating AI-assisted patient pre-screening.

**Core features:**
1. **Patient Triage Pipeline** — 3-5 step symptom interview → AI analysis → specialist recommendation + urgency + justification
2. **Admin Panel** — View/export triaged submissions, manage synthetic data generation
3. **Synthetic Case Generator** — Cron (60s) auto-generates cases via AI so the demo feels alive

**Constraints:**
- Runs entirely on a laptop (32GB unified memory AMD AI CPU)
- All data is synthetic (no real patient data)
- AI calls use DeepSeek V4 Pro/Flash via `symfony/ai`
- 2-week development window with OpenCode + AI agents

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Backend Framework | Symfony 7.4 | Market demand (all top offers), `symfony/scheduler` for cron, `symfony/ai` for AI |
| Frontend Framework | React 19 + Vite + TypeScript | Market frequency (15% of Symfony offers), fast HMR for rapid dev |
| AI Integration | `symfony/ai` (v0.9.0) | Official Symfony package, native DeepSeek support, Agent/Chat/Platform components |
| API Layer | API Platform (admin CRUD) + Manual Controllers (triage pipeline) | Shows both productivity and senior-level architecture |
| Architecture Style | DDD Light (Bounded Contexts) | Inspired by CodelyTV/php-ddd-example, sufficient for 2-week scope |
| Async Processing | Symfony Messenger + Scheduler | Handles AI calls asynchronously, cron-based synthetic generation |
| Database | PostgreSQL (primary) | Better JSON support for AI responses, growing market demand (20% of offers) |
| Testing | PHPUnit (backend) + Vitest (frontend) | PHPUnit appears in 45% of senior Symfony offers |
| Containerization | Docker (dev only) | 60% of offers require Docker; TriageFlow uses it for local dev consistency |

## Agent & Skill Mapping

### OpenCode Agents (invoked via Task tool)

| Agent | Role | When to Use |
|-------|------|-------------|
| `symfony-specialist` | Symfony 7.x patterns, Doctrine, Messenger, symfony/ai | Backend code, API design, AI integration |
| `frontend-developer` | React + TypeScript components, Vite, Tailwind | Frontend UI, state management, API client |
| `backend-developer` | General backend architecture | Cross-cutting concerns, data modeling |
| `api-designer` | REST API design, JSON:API conventions | API endpoint design, OpenAPI docs |
| `code-reviewer` | Code quality, security, best practices | Before commits, PR review |
| `docker-expert` | Docker Compose, container configuration | Dev environment setup |
| `documentation-engineer` | Technical docs, agents.md, API docs | Documentation updates |
| `test-automator` | Test generation, coverage | Adding test suites |

### Skills (loaded via Skill tool)

```bash
# Before ANY creative work (features, components, behaviors)
skill("brainstorming")

# Before writing new features, fixing bugs, refactoring  
skill("test-driven-development")

# When encountering bugs, test failures, unexpected behavior
skill("systematic-debugging")

# Before claiming work is complete
skill("verification-before-completion")

# When receiving code review feedback
skill("receiving-code-review")
```

### Project-Specific Skill

```bash
# Load TriageFlow conventions (DDD, AI pipeline, medical domain)
skill("triageflow")
```
Location: `.opencode/skills/triageflow/SKILL.md`

## Development Workflow

### Phase 1: Foundation (Days 1-2)
- [x] Infrastructure blueprint (this session)
- [ ] Symfony 7.4 API skeleton with Docker
- [ ] React + Vite + TypeScript frontend skeleton
- [ ] symfony/ai integration with DeepSeek
- [ ] Database schema + Doctrine entities

### Phase 2: Core Pipeline (Days 3-4)
- [ ] Patient intake endpoints (symptom questionnaire)
- [ ] AI triage analysis (symfony/ai Agent component)
- [ ] Admin CRUD (API Platform)
- [ ] Triage submission flow end-to-end

### Phase 3: Demo Polish (Days 5-6)
- [ ] Synthetic case generator (symfony/scheduler)
- [ ] Admin dashboard with stats
- [ ] Frontend patient interview UI
- [ ] Responsive design + dark mode

### Phase 4: Hardening (Days 7-10)
- [ ] Tests (PHPUnit + Vitest, 80%+ coverage)
- [ ] Error handling + retry logic
- [ ] Performance optimization
- [ ] Documentation

### Workflow Rules

1. **Brainstorm before building** — always invoke `brainstorming` skill before new features
2. **TDD mandatory** — invoke `test-driven-development` for features/bugfixes
3. **Single-responsibility commits** — `feat:`, `fix:`, `docs:`, `refactor:`
4. **Verify before claiming done** — invoke `verification-before-completion`
5. **Code review before merge** — use `code-reviewer` agent

## Convention Rules

### Always
- [ ] Load `@backend/agents.md` before touching backend code
- [ ] Load `@frontend/agents.md` before touching frontend code
- [ ] Write tests before implementation (TDD)
- [ ] Use strict types (`declare(strict_types=1)`) in PHP
- [ ] Use TypeScript strict mode in frontend
- [ ] All AI calls go through `symfony/ai` Platform component
- [ ] Synthetic data ONLY — never real patient data (even in tests)

### Never
- [ ] Skip code review before merging
- [ ] Use `any` in TypeScript
- [ ] Commit secrets or API keys
- [ ] Mix business logic in controllers
- [ ] Skip error handling for AI calls

## Directory Structure

```
triageflow/
├── agents.md                    # THIS FILE — master agent configuration
├── .opencode/
│   ├── config.json              # OpenCode configuration
│   └── skills/
│       └── triageflow/
│           └── SKILL.md         # Project-specific conventions skill
├── backend/                     # Symfony 7.4 API
│   ├── agents.md                # Backend-specific coding rules
│   ├── config/
│   │   └── packages/
│   │       └── ai.yaml          # symfony/ai DeepSeek configuration
│   ├── src/
│   │   ├── Triage/              # Bounded Context: Triage Pipeline
│   │   │   ├── Application/     # Commands, Queries, Handlers
│   │   │   ├── Domain/          # Entities, Value Objects, Repositories
│   │   │   └── Infrastructure/  # Controllers, API Platform Resources
│   │   ├── Admin/               # Bounded Context: Admin Panel
│   │   └── Reporting/           # Bounded Context: Statistics
│   ├── tests/
│   └── docker-compose.yml
└── frontend/                    # React 19 + Vite + TypeScript
    ├── agents.md                # Frontend-specific coding rules
    ├── src/
    │   ├── components/          # Reusable UI components
    │   ├── features/            # Feature-specific pages/modules
    │   ├── api/                 # API client and types
    │   └── hooks/               # Custom React hooks
    └── tests/
```

## Related Files

- `backend/agents.md` — Symfony 7.4 backend rules
- `frontend/agents.md` — React frontend rules
- `.opencode/skills/triageflow/SKILL.md` — Domain-specific conventions
- `.opencode/config.json` — OpenCode configuration
- https://github.com/CodelyTV/php-ddd-example — Architecture inspiration
- https://github.com/symfony/ai — Official symfony/ai package

## Maintenance

Update this file when:
- Tech stack changes (new packages, version bumps)
- Architecture decisions evolve
- New bounded contexts are added
- Agent/Skill mappings change
- Workflow rules are refined

## Agent skills

### Issue tracker

Issues live as GitHub Issues in `psswid/triageflow-docs`. See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the default five canonical triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.
