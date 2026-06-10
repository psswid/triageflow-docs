# TriageFlow

AI-assisted patient pre-screening demonstration system. A 2-week portfolio project that simulates a medical triage pipeline using synthetic data and LLM-powered analysis. Primary goal is demonstrating full-stack development proficiency with **Symfony 7.4 + React 19 + AI** — not medical accuracy.

> **Project Status:** This is a portfolio demo. All data is synthetic. Do not use for actual medical decisions.

## Repository Landscape

TriageFlow is split across three independent git repositories:

| Repo | Remote | What's Inside |
|------|--------|---------------|
| **triageflow-docs** _(this repo)_ | `git@github.com:psswid/triageflow-docs.git` | Documentation, ADRs, OpenCode config, agents, issues |
| **triageflow-backend** | `git@github.com:psswid/triageflow-backend.git` | Symfony 7.4 PHP API, PostgreSQL 16, Docker |
| **triageflow-frontend** | `git@github.com:psswid/triageflow-frontend.git` | React 19 SPA, Vite 8, TypeScript, Tailwind CSS 4 |

Each repo has its own commit history, CI pipeline, and dependency tree — they are not submodules or a monorepo. ([ADR-0003](docs/adr/0003-separate-git-repos.md))

## Repo Structure

```
triageflow-docs/
├── CONTEXT.md                    # Domain language & terminology (read first)
├── agents.md                     # Master agent configuration for OpenCode
├── README.md                     # ← You are here
├── .opencode/                    # OpenCode AI agent config & skills
│   ├── config.json
│   ├── opencode.json
│   └── skills/
├── docs/
│   ├── operating-guide.md        # How to run dev sessions
│   ├── adr/                      # Architecture Decision Records (6 ADRs)
│   ├── testing/
│   │   └── manual-test-stories.md # Step-by-step browser test stories
│   ├── agents/                   # Agent skill configurations
│   ├── handoffs/                 # Session handoff documents
│   ├── status/                   # Project status tracking
│   ├── task-template.md          # Session start template
│   ├── tools-scenarios-backend.md
│   ├── tools-scenarios-frontend.md
│   └── tools-scenarios-matrix.md
├── backend/                      # Local clone of triageflow-backend
├── frontend/                     # Local clone of triageflow-frontend
└── raw_log.md
```

## Quick Start (Local Development)

From the local monorepo checkout (where `backend/` and `frontend/` are cloned as siblings):

```bash
# 1. Start the backend (Docker)
cd backend
docker compose up -d            # PHP 8.4 + Nginx + PostgreSQL 16
cp .env.example .env            # Configure environment
php bin/console lexik:jwt:generate-keypair  # Generate JWT keys

# 2. In another terminal, start the frontend
cd frontend
npm install
npm run dev                     # Vite dev server on :5173

# 3. Run tests
cd backend && php bin/phpunit                   # 204 tests, 644 assertions
cd frontend && npm test                          # Vitest
cd frontend && npx playwright test               # E2E (requires Docker backend)
```

**Key URLs:**
- Backend API: `http://localhost:8000`
- Frontend SPA: `http://localhost:5173`

## Email Verification (Local Development)

This project uses **Mailpit** for local email testing. When you register a new user, a verification email is sent.

### Creating a New User

1. Start the backend: `cd backend && docker compose up -d`
2. Navigate to `http://localhost:5173/register`
3. Enter your email and password (minimum 8 characters)
4. Confirm your password
5. Submit the form
6. Open [Mailpit](http://localhost:8025) to see the verification email
7. Click the verification link to activate your account
8. Login with your credentials

### Accessing Emails

- **Web UI:** [http://localhost:8025](http://localhost:8025)
- **SMTP:** `localhost:1025` (configured in Symfony's `MAILER_DSN`)

## Key Documentation

| Document | What It Covers |
|----------|----------------|
| [CONTEXT.md](CONTEXT.md) | Domain language — read first. Defines Triage Submission, User, Admin, Turn, TriageOutcome, Synthetic Case |
| [agents.md](agents.md) | OpenCode agent configuration, skills, development workflow |
| [docs/operating-guide.md](docs/operating-guide.md) | How to run dev sessions, skill invocation, repo layout |
| [docs/adr/](docs/adr/) | Architecture Decision Records (6 decisions documented) |
| [docs/testing/manual-test-stories.md](docs/testing/manual-test-stories.md) | 10 manual test stories with step-by-step browser instructions |
| [docs/task-template.md](docs/task-template.md) | Session start template — copy and fill for every session |
| [docs/tools-scenarios-backend.md](docs/tools-scenarios-backend.md) | Symfony/Doctrine/AI tool patterns |
| [docs/tools-scenarios-frontend.md](docs/tools-scenarios-frontend.md) | React/Vite/TanStack/Tailwind patterns |

## First-Time Agent Setup

If you're setting up a new AI agent environment for this project:

```bash
# 1. Install Matt Pocock skills (if not already installed)
npx skills@latest add mattpocock/skills
# Select: setup-matt-pocock-skills, grill-with-docs, handoff,
#         to-issues, zoom-out, caveman

# 2. Run setup (creates docs/agents/*.md + updates agents.md)
#    This is already done — see docs/operating-guide.md

# 3. Create GitHub issue labels (after gh auth)
gh label create "needs-triage" --color "d73a4a" --repo psswid/triageflow-docs
gh label create "needs-info" --color "0075ca" --repo psswid/triageflow-docs
gh label create "ready-for-agent" --color "0e8a16" --repo psswid/triageflow-docs
gh label create "ready-for-human" --color "fbca04" --repo psswid/triageflow-docs
gh label create "wontfix" --color "ffffff" --repo psswid/triageflow-docs
```

## Architecture Decisions

All decisions documented as ADRs in [docs/adr/](docs/adr/):

- **0001:** OpenRouter free models (Gemma 4, GPT-OSS) instead of paid API
- **0002:** Custom AI client over `symfony/ai` bundle
- **0003:** Separate git repos for backend and frontend
- **0004:** Single aggregate — TriageSubmission with embedded TriageOutcome value object
- **0005:** JSON column for conversation history (no join tables)
- **0006:** System user with sentinel UUID for synthetic cases

## Domain Language

This project uses precise terminology. Key terms defined in [CONTEXT.md](CONTEXT.md):

- **Triage Submission** — Complete symptom report with conversation history + AI result
- **User** — Self-registered person who submits symptoms (not "Patient")
- **Admin** — Monitors dashboard, manages synthetic case generation
- **Turn** — One exchange in the triage interview (up to 3)
- **TriageOutcome** — Embedded value object: specialist, urgency, justification
- **Synthetic Case** — AI-generated submission for demo purposes

## Related Repositories

- [triageflow-backend](https://github.com/psswid/triageflow-backend) — Symfony 7.4 API
- [triageflow-frontend](https://github.com/psswid/triageflow-frontend) — React 19 SPA
