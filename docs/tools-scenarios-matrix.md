# TriageFlow — Tools × Scenarios Matrix

> Complete development process map: every scenario, every tool, every gate.
> **For domain-specific scenarios:** [`tools-scenarios-backend.md`](tools-scenarios-backend.md) (Symfony) | [`tools-scenarios-frontend.md`](tools-scenarios-frontend.md) (React)
> Origin tags: 🦸 Superpowers | 🧔 Matt Pocock | 🏠 Project (triageflow)

---

## Scenario 1: New Feature (existing module)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🧠 Align | Shared language, domain model, ADRs | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | Subtask breakdown, parallel batches | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🎫 Issues | Plan → independently-grabbable GitHub issues | `skill("to-issues")` | 🧔 |
| 🔨 Implement | Write code, TDD | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🔭 Context | When agent misses big picture | `skill("zoom-out")` | 🧔 |
| 🧪 Test | Fill coverage gaps | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Quality, security, convention check | `skill("requesting-code-review")` | 🦸 |
| ✅ Verify | Tests pass, lint clean | `skill("verification-before-completion")` | 🦸 |
| 💾 Ship | Semantic commit | `skill("git-workflow")` | 🦸 |
| 📦 Handoff | Session summary → committable .md | `skill("handoff")` | 🧔 |

**Template:** Use `docs/task-template.md` with `## Stage: starting`

---

## Scenario 2: Architecture Change (new bounded context / module / middleware)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Discover patterns, coupling, conventions | `task(subagent="ContextScout")` | 🦸 |
| 📚 Research | Fetch external library docs (new packages) | `task(subagent="ExternalScout")` | 🦸 |
| 🧠 Align | Domain language, architectural ADRs | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | Dependency graph, rollout order, parallel batches | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🔨 Implement | Build in dependency order, context-isolated | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🔭 Context | System-level perspective during implementation | `skill("zoom-out")` | 🧔 |
| 🧪 Test | Integration contracts + unit coverage | `task(subagent="TestEngineer")` | 🦸 |
| 📝 Document | Update agents.md, patterns, conventions | `task(subagent="DocWriter")` | 🦸 |
| 👁️ Review | Boundary integrity, architectural consistency | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Full suite, no broken contracts | `skill("verification-before-completion")` | 🦸 |
| 📦 Handoff | Architecture decisions snapshot | `skill("handoff")` | 🧔 |

---

## Scenario 3: Debugging (bug report / QA feedback / regression)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🐛 Reproduce | Isolate, capture exact failure | Manual + `bash: run failing test` | — |
| 🔍 Diagnose | Root cause, eliminate possibilities | `skill("systematic-debugging")` | 🦸 |
| 🔎 Explore | Find all related code paths | `task(subagent="explore")` (quick/narrow → very thorough) | 🦸 |
| 🔭 Context | Understand affected area systemically | `skill("zoom-out")` | 🧔 |
| 📋 Plan fix | Minimal scope, regression risk | Quick verbal plan (2-3 bullets) | — |
| 🔨 Fix | Red → green → refactor | `skill("tdd-workflow")` | 🦸 |
| 👁️ Review | Fix correctness, no side effects | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Bug gone, no regression | `skill("verification-before-completion")` | 🦸 |

---

## Scenario 4: Code Review Response

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📖 Understand | Parse feedback, find underlying concern | `skill("receiving-code-review")` | 🦸 |
| 🤔 Decide | Accept / clarify / push back with reasoning | Your judgment | — |
| 🔨 Apply | Implement accepted changes | `skill("tdd-workflow")` | 🦸 |
| ✅ Verify | Changes don't break anything | `skill("verification-before-completion")` | 🦸 |

---

## Scenario 5: Refactoring (no behavior change)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Map | Find all usages, callers, dependents | `task(subagent="ContextScout")` + `task(subagent="explore")` | 🦸 |
| 🧪 Baseline | Run full test suite, capture results | `bash: run tests` | — |
| 📋 Plan | Scope, sequence, rollback strategy | Quick verbal plan | — |
| 🔨 Refactor | Incremental changes, green after each step | `task(subagent="CoderAgent")` | 🦸 |
| 🔭 Context | System-level perspective before refactoring | `skill("zoom-out")` | 🧔 |
| 👁️ Review | Patterns improved, behavior preserved | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Identical test results pre/post | `skill("verification-before-completion")` | 🦸 |

---

## Scenario 6: Documentation (new docs / updating agents.md / onboarding)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | What changed? What's missing? | Read diff, changelog, git log | — |
| 📝 Write | Generate docs matching project conventions | `task(subagent="DocWriter")` | 🦸 |
| 👁️ Review | Accuracy, clarity, completeness | `task(subagent="CodeReviewer")` | 🦸 |
| 📊 Audit | Cross-check all project docs for staleness | `skill("repo-scan")` | 🦸 |

---

## Scenario 7: Docker / Infrastructure

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🐳 Design | Container strategy, volumes, networks | `skill("docker-patterns")` | 🦸 |
| 🔨 Build | Dockerfile, compose, env vars | `task(subagent="OpenDevopsSpecialist")` | 🦸 |
| ✅ Verify | Containers start, services healthy | `bash: docker compose up --build` | — |

---

## Scenario 8: Git Operations (branching, merging, PRs)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🌿 Start | Create isolated workspace for feature | `skill("using-git-worktrees")` | 🦸 |
| 📝 Commit | Semantic, single-responsibility | `skill("git-workflow")` | 🦸 |
| 🔀 Integrate | Merge/rebase, conflict resolution | `skill("git-workflow")` | 🦸 |
| 🏁 Finish | Decide: merge, PR, or cleanup | `skill("finishing-a-development-branch")` | 🦸 |

---

## Scenario 9: First-Time Exploration (new codebase or unfamiliar module)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Scan | Classify files, detect patterns, find deps | `skill("repo-scan")` | 🦸 |
| 🔎 Explore | Answer "how does X work?" | `task(subagent="explore")` (quick/medium/very thorough) | 🦸 |
| 📚 Research | Get current docs for new external libraries | `task(subagent="ExternalScout")` | 🦸 |
| 🧠 Design | Orient before acting | `skill("grill-with-docs")` | 🧔 |
| 📦 Handoff | Document findings for next session | `skill("handoff")` | 🧔 |

---

## Scenario 10: Prompt Improvement

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| ✍️ Optimize | Analyze intent, map to skills/agents | `skill("prompt-optimizer")` | 🦸 |
| ⚠️ Note | Advisory only — never executes. Use before writing task template. | — | — |

---

## Scenario 11: Continuous Improvement (meta)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📊 Learn | Observe sessions, build instincts | `skill("continuous-learning-v2")` | 🦸 |
| 🔧 Create | Build new project-specific skills | `skill("skill-creator")` | 🦸 |
| 📋 Organize | Restructure context files | `task(subagent="ContextOrganizer")` | 🦸 |
| ✨ Optimize | Cut token bloat ~75% in long sessions | `skill("caveman")` | 🧔 |

---

## On-Demand Tools (use anytime, not tied to a scenario)

| Tool | When | Origin |
|------|------|--------|
| `skill("caveman")` | Session is long, token bloat is high | 🧔 |
| `skill("zoom-out")` | Agent doesn't see big picture, tunnel-visioning | 🧔 |
| `skill("handoff")` | End of any session — creates committable .md file | 🧔 |
| `skill("tdd-workflow")` | Writing any new code | 🦸 |
| `skill("verification-before-completion")` | About to claim "done" | 🦸 |

---

## Tools NOT for This Project

| Tool | Reason |
|------|--------|
| `laravel-patterns` | Symfony project |
| `laravel-security` | Symfony project |
| `laravel-tdd` | Symfony project |
| `laravel-verification` | Symfony project |
| `prisma-patterns` | Doctrine ORM, not Prisma |
| Matt Pocock `diagnose` | Prefer `systematic-debugging` (familiar) |
| Matt Pocock `grill-me` | Prefer `grill-with-docs` (adds ADR + CONTEXT.md) |
| Matt Pocock `tdd` | Prefer `tdd-workflow` (familiar) |
| Matt Pocock `write-a-skill` | Prefer `skill-creator` (familiar) |

---

## Quick Reference: "I'm doing X…"

```
New feature?             → grill-with-docs → write-plan → to-issues → tdd → test-engineer → review → verify → handoff
Architecture change?     → context-scout → external-scout → grill-with-docs → write-plan → tdd → doc-writer → review → verify → handoff
Bug?                     → systematic-debugging → explore → zoom-out → tdd → review → verify
Review feedback?         → receiving-code-review → tdd → verify
Refactoring?             → context-scout → baseline-tests → zoom-out → coder → review → verify
Writing docs?            → doc-writer → review
Docker/infra?            → docker-patterns → devops-specialist → verify
Git question?            → git-workflow
Unfamiliar module?       → repo-scan → explore → external-scout → grill-with-docs → handoff
Prompt sucks?            → prompt-optimizer (before writing task template)
Claiming "done"?         → verification-before-completion  ← ALWAYS
Session ending?          → handoff  ← ALWAYS
Token bloat?             → caveman
```

**Shorthand → Full invocation:**
| Shorthand | Full |
|-----------|------|
| `grill-with-docs` | `skill("grill-with-docs")` |
| `write-plan` | `skill("writing-plans")` → `task(subagent="TaskManager")` |
| `to-issues` | `skill("to-issues")` |
| `tdd` | `skill("tdd-workflow")` |
| `test-engineer` | `task(subagent="TestEngineer")` |
| `doc-writer` | `task(subagent="DocWriter")` |
| `review` / `code-review` | `skill("requesting-code-review")` or `task(subagent="CodeReviewer")` |
| `verify` | `skill("verification-before-completion")` |
| `handoff` | `skill("handoff")` |
| `context-scout` | `task(subagent="ContextScout")` |
| `external-scout` | `task(subagent="ExternalScout")` |
| `explore` | `task(subagent="explore")` |
| `systematic-debugging` | `skill("systematic-debugging")` |
| `zoom-out` | `skill("zoom-out")` |
| `caveman` | `skill("caveman")` |
| `coder` | `task(subagent="CoderAgent")` |
| `repo-scan` | `skill("repo-scan")` |
| `docker-patterns` | `skill("docker-patterns")` |
| `devops-specialist` | `task(subagent="OpenDevopsSpecialist")` |
| `git-workflow` | `skill("git-workflow")` |
| `prompt-optimizer` | `skill("prompt-optimizer")` |

---

## Installation Checklist

### Already Installed (Superpowers)
- [x] brainstorming
- [x] test-driven-development
- [x] systematic-debugging
- [x] verification-before-completion
- [x] receiving-code-review
- [x] skill-creator
- [x] docker-patterns
- [x] git-workflow (if installed)

### To Install (Matt Pocock)
Run: `npx skills@latest add mattpocock/skills`

Select:
- [ ] `setup-matt-pocock-skills` — one-time config (issue tracker, labels, docs path)
- [ ] `grill-with-docs` — shared language + ADR
- [ ] `handoff` — session handoff files
- [ ] `to-issues` — plan → GitHub issues
- [ ] `zoom-out` — system-level perspective
- [ ] `caveman` — token optimization (optional)

Then run `/setup-matt-pocock-skills` once per repo.
