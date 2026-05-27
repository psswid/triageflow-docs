# TriageFlow — Tools × Scenarios Matrix

> Complete development process map: every scenario, every tool, every gate.
> **For domain-specific scenarios:** [`tools-scenarios-backend.md`](tools-scenarios-backend.md) (Symfony) | [`tools-scenarios-frontend.md`](tools-scenarios-frontend.md) (React)
> Origin tags: 🦸 Superpowers | 🧔 Matt Pocock | 🏠 Project (triageflow)

---

## Scenario 1: New Feature (existing module)

**When:** Adding a new capability to an existing bounded context or component (e.g., a new triage question type, a new admin report).
**Success:** Feature is defined in CONTEXT.md, broken into independently-grabbable issues, built with TDD, reviewed for quality, and the session is handoff-documented.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🧠 Align | Start every coding session by loading `SCOUT.md`, `CONTEXT.md`, and any relevant agents.md files. Confirm domain terminology before writing anything. Create or update ADRs if this feature introduces new architectural decisions | `skill("grill-with-docs")` → load agents.md + CONTEXT.md | 🧔 |
| 📋 Plan | Break the feature into atomic, verifiable subtasks with dependency tracking. Identify parallel batches (tasks that don't depend on each other). Output: `.tmp/tasks/{feature}/` with task.json + subtask_NN.json files | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🎫 Issues | Convert the plan into independently-grabbable GitHub issues. Each issue is a vertical slice — a tracer bullet through the stack — not a layer-by-layer task list | `skill("to-issues")` | 🧔 |
| 🔨 Implement | Execute subtasks in dependency order. Parallel batches: dispatch multiple CoderAgents simultaneously, wait for all to complete. Sequential batches: run one at a time. Each subtask must pass its own verification gate before the next batch starts | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🔭 Context | Pause mid-implementation when the agent appears to be missing the system-level picture — e.g., doesn't understand how this feature affects other modules, or is producing code that doesn't fit the DDD bounded context boundaries | `skill("zoom-out")` | 🧔 |
| 🧪 Test | After implementation, dispatch TestEngineer to fill coverage gaps. Focus on: edge cases, error paths, validation boundaries, integration contracts with adjacent modules. Never accept "coverage is fine" without actual test files | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Request a review from CodeReviewer with specific focus areas (conventions from agents.md, security, performance, architecture consistency). Don't accept "LGTM" — demand specific findings | `skill("requesting-code-review")` | 🦸 |
| ✅ Verify | Run the full test suite. Verify pre-commit checks (linting, type checks, static analysis). Confirm coverage threshold met (80%). Run any project-specific verification scripts | `skill("verification-before-completion")` | 🦸 |
| 💾 Ship | Create a semantic commit (`feat:` prefix, scope in parentheses, present-tense verb). Use git-worktree patterns if isolation is needed. Before pushing, review the diff yourself — never push blind | `skill("git-workflow")` | 🦸 |
| 📦 Handoff | Compact the session into a committable markdown handoff file. Include: what was done, why, what's next, any blockers or decisions made. This is your continuity artifact when CMP replaces old details | `skill("handoff")` | 🧔 |

⚠️ **Watch out:** The most common failure is starting to code before aligning on domain language. Always load context first — skipped context = broken code. Also: don't skip the handoff at session end. ACP doesn't persist across restarts, and the handoff file is your only continuity.

---

## Scenario 2: Architecture Change (new bounded context / module / middleware)

**When:** Introducing a new DDD bounded context, a new infrastructure middleware, a new database schema area, or any change that affects multiple existing modules.
**Success:** The change is grounded in current architecture understanding, rolled out in dependency order, all contracts are verified, and the architecture decision is recorded in an ADR.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Before designing anything: discover all existing patterns, modules, and coupling points. Check which bounded contexts exist, how they communicate (Messenger events), what conventions the existing code follows. If you find a pattern, follow it — don't invent a new one | `task(subagent="ContextScout")` | 🦸 |
| 📚 Research | If the change requires new packages or upgrades: fetch current documentation for each external dependency. Training data is outdated — never rely on it for library APIs. Check installation steps, API changes, any breaking changes | `task(subagent="ExternalScout")` | 🦸 |
| 🧠 Align | Run grill-with-docs against the proposed architecture. Stress-test: What language does this new module use? What's its responsibility boundary? How does it communicate? Every answer becomes a CONTEXT.md entry or ADR. Don't proceed without this step — undefined language = implementation chaos | `skill("grill-with-docs")` — this is mandatory before any architecture change | 🧔 |
| 📋 Plan | Build a dependency graph: what must exist first before this can work? Generate a rollout plan with parallel batches for independent components and sequential chains for dependent ones. Include rollback steps | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🔨 Implement | Execute in strict dependency order. Each batch: context-isolated CoderAgent with the relevant agents.md loaded. Never let an agent work across bounded context boundaries — dispatch separate agents for each context | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🔭 Context | Between implementation phases, pause and zoom out. Does the partial implementation fit the architecture diagram? Are we drifting from the ADR decisions? | `skill("zoom-out")` | 🧔 |
| 🧪 Test | Integration contracts between contexts are the highest-value tests here. Test the event bus, the message handlers, the cross-context data flow. Unit tests for business logic within each context | `task(subagent="TestEngineer")` | 🦸 |
| 📝 Document | Update agents.md patterns when new conventions emerge. Update CONTEXT.md with the new bounded context's language. Generate or update ADRs for architectural decisions made during implementation | `task(subagent="DocWriter")` | 🦸 |
| 👁️ Review | Review for architectural integrity: boundary violations, leaking abstractions, wrong coupling direction. Each context should depend on abstractions, not concretions. Events should flow one way (not circular) | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Full suite green. No broken contracts between contexts. ADR status updated to "accepted" or "superseded". New bounded context documented in agents.md | `skill("verification-before-completion")` | 🦸 |
| 📦 Handoff | Architecture snapshot: what was created, what it depends on, how to extend it, what's still TBD | `skill("handoff")` | 🧔 |

⚠️ **Watch out:** Architecture changes suffer from two opposite failures: (1) analysis paralysis — endless planning without code, and (2) cowboy architecture — building without understanding existing patterns. grill-with-docs is the cure for both. Also: never let a single CoderAgent span multiple bounded contexts — they lose context window quality and produce inconsistent code.

---

## Scenario 3: Debugging (bug report / QA feedback / regression)

**When:** A specific behavior is wrong: test failure, QA report, production error log, or regression from a recent change.
**Success:** Root cause is found and fixed. The fix is minimal (no refactoring adjacent code "while I'm here"). Regression test is written. No new bugs introduced.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🐛 Reproduce | Create a failing test or reproduction script that captures the exact failure. The test must be minimal — isolate the bug to the smallest reproducible case. If you can't reproduce it, you can't fix it | Manual + `bash: run failing test` | — |
| 🔍 Diagnose | Use systematic debugging: form a hypothesis about the root cause (not the symptom), test it, eliminate it, form the next hypothesis. Never skip from symptom to fix — you'll fix the wrong thing | `skill("systematic-debugging")` | 🦸 |
| 🔎 Explore | When the bug spans multiple files: find all code paths that touch the failing behavior. Check callers, check dependents, check if the same pattern exists elsewhere (it might be broken there too) | `task(subagent="explore")` (quick/narrow → very thorough) | 🦸 |
| 🔭 Context | Before fixing, understand the affected area systemically. What does this code connect to? What assumptions does it make? A fix that's correct locally can break things globally | `skill("zoom-out")` | 🧔 |
| 📋 Plan fix | Verbalize the fix in 2-3 bullets before writing code. "The problem is X. The root cause is Y. The fix is Z." If you can't state it this concisely, you don't understand it yet — keep diagnosing | Quick verbal plan (2-3 bullets) | — |
| 🔨 Fix | Write the failing test first (if not done in reproduce), then the minimal code change to make it green. Red → green → refactor. A fix that touches more than 3 files or 50 lines is probably over-engineered | `skill("tdd-workflow")` | 🦸 |
| 👁️ Review | Review the fix, not the bug. Focus: Is this truly the root cause? Could this same bug exist elsewhere? Does the fix change any contracts or assumptions? Are there edge cases the test didn't cover? | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Bug is gone (original reproduction test passes). No regressions (full suite passes). If the bug was in production, add a regression test and consider if you need a similar check elsewhere | `skill("verification-before-completion")` | 🦸 |

⚠️ **Watch out:** The #1 debugging failure is fixing symptoms instead of root causes. If your fix is in a controller but the bug is in a repository, you're bandaging. The #2 failure is scope creep during debugging — "while I'm here I'll refactor this too." Don't. Fix the bug, commit, then refactor separately. Also: never skip the regression test. Bugs that come back are worse than bugs that never left.

---

## Scenario 4: Code Review Response

**When:** You receive code review feedback — comments, suggestions, change requests — and need to process them without blindly accepting everything or getting defensive.
**Success:** Feedback is understood (not just read), each item gets a reasoned decision (accept / clarify / push back), accepted changes are implemented and verified, no new issues introduced.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📖 Understand | Before implementing anything: read every comment. Find the underlying concern behind each suggestion. A comment about "use a different variable name" might really mean "this code is hard to understand." Process feedback with technical rigor, not performative agreement | `skill("receiving-code-review")` | 🦸 |
| 🤔 Decide | For each feedback item: Accept (it's correct), Clarify (you don't understand the concern), or Push back (you have a technical reason to disagree). Document your reasoning. Never accept feedback you don't understand — ask for clarification | Your judgment | — |
| 🔨 Apply | Implement accepted changes one at a time. Each change: write a test if the feedback revealed a missing case, apply the change, verify green. Don't batch changes — do them sequentially so you can isolate any regressions | `skill("tdd-workflow")` | 🦸 |
| ✅ Verify | Full suite green after all changes. If any change required rewriting logic, re-review the affected area for side effects. The goal is cleaner code, not broken code | `skill("verification-before-completion")` | 🦸 |

⚠️ **Watch out:** Two extremes to avoid: (1) accepting everything without question — you're the engineer, you own the code. (2) rejecting everything defensively — the reviewer saw something you didn't. The sweet spot: understand the concern, then decide. Also: implementing feedback that contradicts your project's conventions (agents.md) is worse than not implementing it — conventions override reviewer preference.

---

## Scenario 5: Refactoring (no behavior change)

**When:** Improving code structure, patterns, or readability without adding features or changing behavior. The test suite should pass identically before and after.
**Success:** Code is cleaner, patterns are more consistent, behavior is 100% preserved. Pre-refactor and post-refactor test results are identical.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Map | Find every usage of what you're changing. For a class rename: find all imports, type hints, and DI config references. For a method change: find all callers, subclass overrides, and tests that reference it. Missing one caller = broken build | `task(subagent="ContextScout")` + `task(subagent="explore")` | 🦸 |
| 🧪 Baseline | Run the full test suite and capture the results. Save the output. This is your contract: any test that passes before MUST pass after. No exceptions for "I improved it" | `bash: run tests` | — |
| 📋 Plan | Scope the refactoring: what changes, in what order, and (critically) what does NOT change. If the refactoring touches more than 5 files, break it into sequential tasks. Each step should be independently testable and reversible | Quick verbal plan | — |
| 🔨 Refactor | Incremental changes. After each change: run the affected tests, verify green. If a change breaks something, undo it before proceeding. Never stack changes thinking "I'll fix it all at the end." That's how you lose track of what broke what | `task(subagent="CoderAgent")` | 🦸 |
| 🔭 Context | When refactoring a module, understand what it touches systemically. A refactoring that improves file A but worsens the overall architecture is a net negative | `skill("zoom-out")` | 🧔 |
| 👁️ Review | Patterns improved (not just changed). Behavior genuinely preserved (review the diff — did anything change that shouldn't have?). The code is more consistent with project conventions, not just "different" | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Test results identical (not "close" — identical). No new linting warnings. No new static analysis issues. Coverage unchanged or improved (never decreased by refactoring) | `skill("verification-before-completion")` | 🦸 |

⚠️ **Watch out:** The #1 refactoring trap: "while I'm refactoring this, I'll also improve that." That's how a 1-hour refactoring becomes a 3-day feature rewrite. Cut scope brutally. If you find something else to fix, write it down and do it in a separate change. Also: never refactor without a baseline test suite. If you don't have tests, write characterization tests first — they capture current behavior, not ideal behavior.

---

## Scenario 6: Documentation (new docs / updating agents.md / onboarding)

**When:** Creating new documentation, updating agents.md with new conventions, writing onboarding guides, or auditing existing docs for staleness.
**Success:** Documentation follows project conventions, is accurate (verified against code), is concise (high signal, low filler), and includes version/date stamps.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Determine what changed: read the diff, changelog, recent commits, or interview the team. Don't document what you think changed — document what actually changed | Read diff, changelog, git log | — |
| 📝 Write | Generate documentation using project templates and conventions. Load `agents.md` and the relevant domain agents.md files first — every doc must match project voice and structure. Include examples where they help, skip them where they don't | `task(subagent="DocWriter")` | 🦸 |
| 👁️ Review | Accuracy: does the doc describe what the code actually does? Clarity: can someone unfamiliar understand this in one read? Completeness: are edge cases, error states, and prerequisites covered? | `task(subagent="CodeReviewer")` | 🦸 |
| 📊 Audit | Cross-check ALL project docs for staleness and inconsistency. A doc that says one thing while the code says another is worse than no doc at all. Check version stamps — has anything changed since last update? | `skill("repo-scan")` | 🦸 |

⚠️ **Watch out:** Documentation has two failure modes: (1) over-documenting — explaining obvious things, writing tutorials for every function, filling docs with fluff. High-signal docs: one clear sentence beats three vague paragraphs. (2) stale docs — documentation that's wrong is actively harmful. The code is the source of truth; docs that contradict it must be updated or deleted. Also: never create new doc files without updating the navigation index.

---

## Scenario 7: Docker / Infrastructure

**When:** Setting up or modifying Docker Compose, creating Dockerfiles, configuring container networking, volumes, or multi-service orchestration for local development.
**Success:** Containers build and start cleanly, services are healthy, volumes persist data, networking between services works, environment variables are properly configured.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🐳 Design | Define container strategy: which services get containers, how they communicate (Docker network), how data persists (volumes), which ports are exposed. For TriageFlow: PostgreSQL, Symfony backend, React dev server, optionally Redis for Messenger | `skill("docker-patterns")` | 🦸 |
| 🔨 Build | Create or modify Dockerfile (multi-stage builds for production), docker-compose.yml (dev environment with hot-reload), .env configuration. Use named volumes for DB data (never lose dev data on container restart). Health checks for dependent services | `task(subagent="OpenDevopsSpecialist")` | 🦸 |
| ✅ Verify | `docker compose up --build` → all services start without errors. Run `docker compose ps` → all services healthy. Backend can connect to PostgreSQL. Frontend dev server available on configured port. Hot reload works on both backend and frontend | `bash: docker compose up --build` | — |

⚠️ **Watch out:** Never commit secrets (passwords, API keys) in docker-compose.yml or Dockerfiles — use `.env` with `.env.example` template. Never volume-mount `node_modules` or `vendor` from host to container (OS/platform differences). Always use health checks for databases before starting dependent services (`depends_on` + `condition: service_healthy`). Multi-stage builds in Dockerfiles dramatically reduce image size — use them.

---

## Scenario 8: Git Operations (branching, merging, PRs)

**When:** Starting feature work, creating branches, committing, merging, rebasing, resolving conflicts, or creating pull requests.
**Success:** Work is isolated, commits are semantic and single-responsibility, branches are cleanly integrated, and PRs are reviewable.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🌿 Start | Create an isolated workspace for feature work. For complex features: use git worktrees to work on multiple branches simultaneously without stashing. For simple work: a feature branch from main is sufficient | `skill("using-git-worktrees")` | 🦸 |
| 📝 Commit | Semantic commits with prefixes: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`. Scope in parentheses: `feat(triage):`. Each commit is one logical change — no "fix X and also refactor Y and update docs" commits | `skill("git-workflow")` | 🦸 |
| 🔀 Integrate | Before merging: fetch upstream, rebase onto latest main (rewrite your history to play it cleanly on top). Resolve conflicts file by file — never use `--theirs` or `--ours` blindly. After rebase: re-run tests to verify nothing broke | `skill("git-workflow")` | 🦸 |
| 🏁 Finish | Decide: merge to main (feature is complete and reviewed), or open PR (needs review first), or cleanup (abandoned branch). Before any merge: verify all pre-commit checks pass, coverage threshold met, no work-in-progress commits | `skill("finishing-a-development-branch")` | 🦸 |

⚠️ **Watch out:** Never force-push to shared branches (`main`, `develop`). Never amend commits that have been pushed and pulled by others. Never commit generated files (migrations are an exception — review them first). Rebase on your own branches, merge on shared branches. The `.gitignore` in the docs-repo intentionally excludes `backend/` and `frontend/` — they have their own repos and git histories.

---

## Scenario 9: First-Time Exploration (new codebase or unfamiliar module)

**When:** Landing in a codebase or module you've never seen — or coming back after a long break. Need to understand structure, patterns, and conventions before doing anything else.
**Success:** You can answer "how does X work?" for the relevant area. You know where things live, what patterns are used, and what dependencies exist. You have enough context to start making changes confidently.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Scan | Classify every file in the target area: what's source code, what's test, what's config, what's vendor. Detect embedded third-party libraries. Get an actionable verdict per module: "healthy", "needs cleanup", "high risk" | `skill("repo-scan")` | 🦸 |
| 🔎 Explore | Ask questions about the codebase: "How are API endpoints structured?", "What's the entity lifecycle?", "How does error handling work?" Use quick for single-file questions, medium for cross-file patterns, very thorough for system-wide understanding | `task(subagent="explore")` (quick/medium/very thorough) | 🦸 |
| 📚 Research | If the codebase uses external libraries or frameworks you haven't worked with recently: fetch current documentation. Training data about external APIs is guaranteed to be stale | `task(subagent="ExternalScout")` | 🦸 |
| 🧠 Design | Before writing any code: run grill-with-docs to build shared language. What does this module call things? What words reappear in class names, method names, and comments? These are the domain terms — internalize them before you write anything | `skill("grill-with-docs")` | 🧔 |
| 📦 Handoff | Document your findings: what you learned, where things live, patterns you observed, gaps you noticed, what's next. This is gold for your future self and for anyone else who lands here | `skill("handoff")` | 🧔 |

⚠️ **Watch out:** Don't trust your instincts in a new codebase — your first assumption about how something works is usually wrong. Use explore and repo-scan BEFORE forming opinions. Don't propose architecture changes on day one — you don't know why things are the way they are yet. The code that looks "wrong" often has a historical reason that makes it right. Understand first, judge later.

---

## Scenario 10: Prompt Improvement

**When:** Your task template or prompt isn't producing the results you want — the agent misunderstands the task, misses context, produces inconsistent output, or the session gets bloated.
**Success:** The optimized prompt produces consistent, context-aware, high-quality agent output with less token bloat.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| ✍️ Optimize | Feed your raw prompt or task template to the optimizer. It analyzes intent, identifies gaps (missing context, unclear scope, ambiguous language), and maps to appropriate skills/commands/agents. Advisory only — it never executes the task itself | `skill("prompt-optimizer")` | 🦸 |
| ⚠️ Note | Use BEFORE writing the task template, not during execution. The optimizer's output is a recommendation — you decide what to adopt | — | — |

⚠️ **Watch out:** Don't confuse prompt optimization with code optimization. It's about how you communicate with agents, not about code performance. Also: an optimized prompt doesn't replace the task template — the template provides structure, the optimizer improves clarity within that structure.

---

## Scenario 11: Continuous Improvement (meta)

**When:** You want to improve the development process itself — create new skills, evolve project patterns, restructure context files, or reduce session token usage.
**Success:** The process gets better over time. New patterns are captured as instincts, skills evolve from observations, context stays organized, and sessions stay lean.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📊 Learn | The learning system observes sessions via hooks, creates atomic instincts (observed patterns) with confidence scoring, and evolves high-confidence instincts into skills/commands/agents. Project-scoped: instincts from this project don't leak to others | `skill("continuous-learning-v2")` | 🦸 |
| 🔧 Create | When you need a new project-specific skill (e.g., a TriageFlow domain skill, a testing helper, a code generation pattern): use the skill creator. It measures performance with evals and variance analysis | `skill("skill-creator")` | 🦸 |
| 📋 Organize | When context files grow scattered or stale: restructure them into function-based organization. Extract patterns from summaries into permanent context. Validate context integrity (no dead links, no contradictions) | `task(subagent="ContextOrganizer")` | 🦸 |
| ✨ Optimize | When the session has 100+ messages or token bloat is visibly degrading agent quality: switch to caveman mode. Cuts token usage ~75% by dropping filler while keeping technical accuracy. Use `/caveman` or say "caveman mode" | `skill("caveman")` | 🧔 |

⚠️ **Watch out:** Meta-work (improving the process) should never block shipping work. Don't spend a day creating a perfect skill when a good enough one takes an hour. The instinct system works best when you let it observe naturally — don't force it. Caveman mode is for when context is actually bloated, not as a default mode — you lose nuance for edge cases.

---

## On-Demand Tools (use anytime, not tied to a scenario)

| Tool | When | Origin |
|------|------|--------|
| `skill("caveman")` | Session is long (100+ messages), token bloat is visibly degrading agent quality, or you just want faster iteration | 🧔 |
| `skill("zoom-out")` | Agent doesn't see big picture, is tunnel-visioning on implementation details, or you need to understand how a change fits the system | 🧔 |
| `skill("handoff")` | End of ANY session — creates a committable .md file that preserves what happened, why, and what's next. DCP compresses old content; handoffs survive | 🧔 |
| `skill("tdd-workflow")` | Writing ANY new code (not just features — bug fixes too). Red → green → refactor. Don't skip it for "trivial" changes | 🦸 |
| `skill("verification-before-completion")` | About to claim "done", commit, push, or open a PR. Evidence before assertions — always | 🦸 |
| `task(subagent="ContextScout")` | At the start of any task that touches existing code — discover what patterns, conventions, and context files exist before you touch anything | 🦸 |
| `task(subagent="ExternalScout")` | Any time a task mentions an external library or framework. Training data is outdated; ExternalScout fetches current docs | 🦸 |

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
New feature?             → grill-with-docs → write-plan → to-issues → tdd → parallel-CoderAgents → test-engineer → review → verify → handoff
Architecture change?     → context-scout → external-scout → grill-with-docs → write-plan → tdd → doc-writer → review → verify → handoff
Bug?                     → systematic-debugging → explore → zoom-out → tdd → review → verify
Review feedback?         → receiving-code-review → tdd → verify
Refactoring?             → context-scout → baseline-tests → zoom-out → coder → review → verify
Writing docs?            → doc-writer → review → repo-scan (audit for staleness)
Docker/infra?            → docker-patterns → devops-specialist → docker-compose-up → verify
Git question?            → git-worktree → git-workflow → finishing-branch
Unfamiliar module?       → repo-scan → explore → external-scout → grill-with-docs → handoff
Prompt sucks?            → prompt-optimizer (advisory — use before writing task template)
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
| `finishing-branch` | `skill("finishing-a-development-branch")` |
| `git-worktree` | `skill("using-git-worktrees")` |

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
- [x] git-workflow

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
