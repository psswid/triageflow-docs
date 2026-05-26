# Task: [Feature name]

> {OpenAgent reads agents.md + project context automatically}

## Stage

`starting` | `continuing` | `debugging` | `reviewing` | `handoff`

## Context Dependencies

- [ ] Load: `agents.md` (master project rules)
- [ ] Load: `backend/agents.md` (if backend work)
- [ ] Load: `frontend/agents.md` (if frontend work)
- [ ] Load: `skill("triageflow")` (if domain/medical logic)
- [ ] Use: `ContextScout` → discover additional patterns
- [ ] Use: `ExternalScout` → fetch current docs (if new external packages)

## Pipeline

Check as you go — this IS your workflow.

### Core Pipeline
- [ ] 🧠 **align**      → `skill("grill-with-docs")` → shared language + ADR
- [ ] 📋 **plan**       → `skill("writing-plans")` → task breakdown
- [ ] 🎫 **issues**     → `skill("to-issues")` → GitHub issues (optional, for team tracking)
- [ ] 🔨 **implement**  → `skill("tdd-workflow")` → `task(subagent="TaskManager")` (if 4+ files) or `task(subagent="CoderAgent")` → code
- [ ] 🧪 **test**       → `task(subagent="TestEngineer")` → tests
- [ ] 👁️ **review**     → `skill("requesting-code-review")` → feedback
- [ ] ✅ **verify**     → `skill("verification-before-completion")`
- [ ] 📦 **handoff**    → `skill("handoff")` → committable handoff .md file

### On-Demand Tools
- `skill("zoom-out")` — agent explains code in system context
- `skill("caveman")` — cut token usage ~75% in long sessions
- `skill("systematic-debugging")` — bug appears? Load this before proposing fixes

## Problem / Context

[Your developer-to-developer reasoning, code snippets, what you're trying to solve]
