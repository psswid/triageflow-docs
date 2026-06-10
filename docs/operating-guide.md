# TriageFlow — Operating Guide

> How to run dev sessions efficiently with this agent setup. Read once, keep open as reference.

---

## What Was Just Set Up

`/setup-matt-pocock-skills` configured three things agents need:

| Thing | Where | What it does |
|-------|-------|-------------|
| Issue tracker | GitHub Issues on `triageflow-docs` | `to-issues` creates tickets here. `gh` CLI commands documented in `docs/agents/issue-tracker.md` |
| Triage labels | 5 defaults: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix` | `triage` skill applies these as issues move through pipeline |
| Domain docs | Single-context: one `CONTEXT.md` + `docs/adr/` at root | `grill-with-docs` populates these. Other skills read them to stay in domain language |

---

## Starting a Session

Every session starts from `docs/task-template.md`. Copy it, fill in blanks, paste into OpenCode.

```
docs/task-template.md     ← Always start here
```

Template has 4 sections:
1. **Stage** — `starting` / `continuing` / `finishing` (tells agent what phase you're in)
2. **Context Dependencies** — list files to load before coding (agents.md, backend/agents.md, frontend/agents.md, CONTEXT.md)
3. **Pipeline** — checkboxes for gates: align → plan → issues → implement → test → review → verify → handoff
4. **Problem/Context** — what you're trying to do

---

## Which Docs to Read When

Three scenario files — read the right one for your situation:

| Situation | Read this |
|-----------|-----------|
| Starting ANY coding session | `docs/task-template.md` (fill and paste) |
| "What tools do I use to do X?" (process question) | `docs/tools-scenarios-matrix.md` — 11 process scenarios |
| Backend coding (Symfony, Doctrine, symfony/ai) | `docs/tools-scenarios-backend.md` — 13 Symfony scenarios |
| Frontend coding (React, Vite, TanStack, Tailwind) | `docs/tools-scenarios-frontend.md` — 13 React scenarios |
| Domain language / architecture decisions | `CONTEXT.md` + `docs/adr/` (created by `grill-with-docs`) |
| Agent rules + conventions | `agents.md` (root) → then `backend/agents.md` or `frontend/agents.md` |

Flow:
```
Start session → task-template.md → pick scenario file → follow gate pipeline → handoff at end
```

---

## Key Skills — When to Invoke

Six most common. Others in the scenario files.

| Skill | Invocation | When |
|-------|-----------|------|
| Grill with docs | `skill("grill-with-docs")` | Start of ANY new feature or architecture change. Defines language, creates ADRs. Never skip |
| Write plan + TaskManager | `skill("writing-plans")` → `task(subagent="TaskManager")` | Feature touches 4+ files. Breaks into parallel/sequential subtasks |
| To issues | `skill("to-issues")` | After plan is written. Converts plan → GitHub issues |
| TDD workflow | `skill("tdd-workflow")` | Writing ANY code. Red → green → refactor. Don't skip for "simple" changes |
| Request review | `skill("requesting-code-review")` | After implementation. Gets CodeReviewer to check conventions, security, patterns |
| Verify | `skill("verification-before-completion")` | Before claiming "done." Runs tests, lint, checks. Evidence before assertions |
| Handoff | `skill("handoff")` | End of EVERY session. Creates committable .md. Your continuity when DCP compresses old content |

On-demand:
- `skill("zoom-out")` — agent tunnel-visioning, missing big picture
- `skill("caveman")` — session bloated (100+ messages), cut tokens 75%
- `skill("systematic-debugging")` — bug hunting, root cause analysis

---

## The Core Pipeline (Repeated Every Session)

```
1. 🧠 ALIGN    → grill-with-docs (domain language + ADRs)
2. 📋 PLAN     → writing-plans → TaskManager (subtask breakdown)
3. 🎫 ISSUES   → to-issues (plan → GitHub tickets)
4. 🔨 BUILD    → tdd-workflow → CoderAgent (execute subtasks)
5. 🧪 TEST     → TestEngineer (fill coverage gaps)
6. 👁️ REVIEW   → CodeReviewer (quality + security check)
7. ✅ VERIFY   → verification-before-completion (tests pass, lint clean)
8. 📦 HANDOFF  → handoff (session summary → .md)
```

Shortcut for quick bugs: `systematic-debugging → zoom-out → tdd → review → verify` (skip plan/issues if <3 files)

---

## Repo Layout — Three Repos, One Project

| Repo | GitHub | Contains |
|------|--------|----------|
| `triageflow-docs` | `psswid/triageflow-docs` | OpenCode config, docs, agents.md, raw_log.md. Issues live here |
| `triageflow-backend` | `psswid/triageflow-backend` | Symfony 7.4 backend, separate git history |
| `triageflow-frontend` | `psswid/triageflow-frontend` | React 19 frontend, separate git history |

**How to work across repos:**
- Issues → always in `triageflow-docs`
- Backend code → work in `triageflow/backend/` (has its own `.git/`)
- Frontend code → work in `triageflow/frontend/` (has its own `.git/`)
- Docs/config → work in `triageflow/` root (docs-repo)
- Session handoffs → committed to docs-repo

---

## Quick Reference — Common Terminal Commands

```bash
# Docs repo
git status                    # Check what changed in docs/config
git push                      # Push docs/config changes

# Backend (cd backend first)
php bin/phpunit               # Run backend tests
php bin/console make:entity   # Generate entity
php bin/console make:migration # Generate migration
symfony server:start          # Start dev server

# Frontend (cd frontend first)
npm run dev                   # Start Vite dev server
npm run test                  # Run Vitest tests
npm run build                 # Production build
npx tsc --noEmit              # TypeScript check
```

---

## First-Time Setup (Do Once)

Already done if you just ran `/setup-matt-pocock-skills`:

```bash
# 1. Install Matt Pocock skills
npx skills@latest add mattpocock/skills
# → Select: setup-matt-pocock-skills, grill-with-docs, handoff, to-issues, zoom-out, caveman

# 2. Run setup (creates docs/agents/*.md + updates agents.md)
# → Already done

# 3. Create GitHub labels (after first gh auth)
gh label create "needs-triage" --color "d73a4a" --repo psswid/triageflow-docs
gh label create "needs-info" --color "0075ca" --repo psswid/triageflow-docs
gh label create "ready-for-agent" --color "0e8a16" --repo psswid/triageflow-docs
gh label create "ready-for-human" --color "fbca04" --repo psswid/triageflow-docs
gh label create "wontfix" --color "ffffff" --repo psswid/triageflow-docs
```

---

## Mailpit (Email Testing)

Mailpit runs as part of the Docker stack and captures all outbound emails from the Symfony backend.

| Port | Usage |
|------|-------|
| `1025` | SMTP — Symfony Mailer sends here |
| `8025` | Web UI — view captured emails in browser |

**Workflow:**
1. Register a new user at `http://localhost:5173/register`
2. Open [Mailpit](http://localhost:8025) in your browser
3. The verification email appears instantly
4. Click the verification link to activate the account

**Troubleshooting:**
- If Mailpit isn't running: `docker compose up -d mailpit`
- Check logs: `docker compose logs mailpit`
- Verify web UI: `curl -s -o /dev/null -w "%{http_code}" http://localhost:8025` (should return 200)
