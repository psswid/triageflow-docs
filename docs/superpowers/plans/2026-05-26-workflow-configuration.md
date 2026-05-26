# Workflow Configuration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up TriageFlow's "docs repo" — install Matt Pocock engineering skills, configure the repository to track OpenCode config + docs + personal notes (excluding backend/ and frontend/ which have their own repos), test the complete task template pipeline end-to-end, and commit everything.

**Architecture:** Two-phase rollout. Phase A: install + configure tools (npm CLI, one-time setup skill). Phase B: test the full pipeline using a real but small scenario (generate a CONTEXT.md, create a sample ADR, run a handoff) to verify all skills work together before real development begins.

**Tech Stack:** Node.js 24.16 (already installed), `skills` npm CLI (`npx skills@latest`), Matt Pocock skills (`grill-with-docs`, `handoff`, `to-issues`, `zoom-out`, `caveman`), OpenCode agent runtime.

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `docs/task-template.md` | Already created | Daily task template |
| `docs/tools-scenarios-matrix.md` | Already created | Reference matrix + install checklist |
| `docs/superpowers/plans/2026-05-26-workflow-configuration.md` | Create (this file) | This implementation plan |
| `CONTEXT.md` | Will be created by `grill-with-docs` | Shared language + domain terminology |
| `docs/adr/` | Will be created by `grill-with-docs` | Architecture Decision Records |
| `docs/handoffs/` | Will be created by `handoff` | Session handoff files |
| `.opencode/config.json` | Modify | Register new skills as project skills |
| `raw_log.md` | Will be created | Personal development notes and thoughts |
| `.gitignore` | Will be created | Exclude backend/, frontend/, node_modules/ |

---

### Task 1: Initialize Docs-Repo + Install Matt Pocock Skills

**Files:**
- Create: `.git/` (git repository in triageflow root)
- Modify: `.opencode/skills/` (skills directory populated by installer)

**Repo purpose:** This is the "docs repo" for TriageFlow — it tracks OpenCode config, docs, personal notes. `backend/` and `frontend/` have their own separate repos and will be excluded via `.gitignore` (Task 7).

- [ ] **Step 1: Initialize git repository**

```bash
git init
```

Expected: `Initialized empty Git repository in /home/stefan/dev/projects/triageflow/.git/`

- [ ] **Step 2: Run the skills installer**

```bash
npx skills@latest add mattpocock/skills
```

Expected: Interactive CLI launches. It will:
- Show a list of available skills from the mattpocock/skills repo
- Ask which skills to install
- Ask which coding agents to install them for (select OpenCode)

**User action required:** When prompted, select these skills:
- `setup-matt-pocock-skills`
- `grill-with-docs`
- `handoff`
- `to-issues`
- `zoom-out`
- `caveman`

Make sure to select **OpenCode** as the target agent.

- [ ] **Step 3: Verify skills installed**

```bash
ls .opencode/skills/ && echo "---" && ls ~/.config/opencode/skills/
```

Expected: New skill directories visible (e.g., `grill-with-docs/`, `handoff/`, `to-issues/`, `zoom-out/`, `caveman/`).

- [ ] **Step 4: Commit initial installation**

```bash
git add -A
git commit -m "feat: install Matt Pocock engineering skills (grill-with-docs, handoff, to-issues, zoom-out, caveman)"
```

---

### Task 2: Run One-Time Repo Setup (`/setup-matt-pocock-skills`)

**Files:**
- Will create/modify: `.github/labels.yml` or Linear config (depends on issue tracker choice)
- Will create/modify: repo-level configuration for Matt Pocock skills

- [ ] **Step 1: Run the setup skill in OpenCode**

In your OpenCode session, run:
```
/setup-matt-pocock-skills
```

Expected: The agent asks three questions:
1. Which issue tracker? → Answer: **GitHub Issues** (recommended for portfolio visibility) or **local files** if you prefer offline
2. Triage labels? → Answer: `bug`, `feature`, `enhancement`, `documentation`, `refactor`
3. Where to save docs? → Answer: `docs/` (already established)

- [ ] **Step 2: Verify setup created expected files**

```bash
ls docs/ | grep -E "CONTEXT|adr|handoffs" && echo "Setup files found" || echo "Setup files may need manual check"
```

Expected: Directories/files for CONTEXT.md, adr/, handoffs/ visible or ready to be created by skills.

- [ ] **Step 3: Commit setup artifacts**

```bash
git add -A
git commit -m "feat: run setup-matt-pocock-skills, configure repo for issue tracking + docs layout"
```

---

### Task 3: Test `grill-with-docs` — Generate CONTEXT.md + Sample ADR

**Files:**
- Create: `CONTEXT.md`
- Create: `docs/adr/2026-05-26-project-init.md`

- [ ] **Step 1: Invoke grill-with-docs on the project**

In your OpenCode session, run:
```
/grill-with-docs
```

The agent will interview you about:
- What the project does (TriageFlow: AI-assisted patient triage showcase)
- Domain terminology (triage, submission, synthetic case, urgency level, specialist type)
- Technology stack (Symfony 7.4, React 19, symfony/ai, DeepSeek)
- Architecture decisions

Let it generate a first ADR: `2026-05-26-project-init.md` documenting the initial architecture decisions from `agents.md`.

- [ ] **Step 2: Verify CONTEXT.md was created**

```bash
cat CONTEXT.md | head -20
```

Expected: A file with domain terminology, shared language definitions, project glossary. Should include terms like "triage submission", "synthetic case", "urgency level", "specialist type" mapped to concise definitions.

- [ ] **Step 3: Verify ADR was created**

```bash
ls docs/adr/ && cat docs/adr/2026-05-26-project-init.md | head -20
```

Expected: ADR file exists with ID, title, status ("accepted"), context, decision, consequences sections.

- [ ] **Step 4: Commit**

```bash
git add CONTEXT.md docs/adr/
git commit -m "docs: generate CONTEXT.md + initial ADR via grill-with-docs"
```

---

### Task 4: Test `handoff` — Create First Session Handoff

**Files:**
- Create: `docs/handoffs/` (first handoff file)

- [ ] **Step 1: Invoke handoff at end of current session**

After completing this workflow setup, run:
```
/handoff
```

Expected: The agent compacts the current conversation into a markdown file and saves it to `docs/handoffs/` with a timestamped filename.

- [ ] **Step 2: Verify handoff file created**

```bash
ls docs/handoffs/
```

Expected: At least one `.md` file present. Open it and verify it contains:
- Session summary
- What was accomplished (skills installed, template created, workflow designed)
- Next steps (start Phase 1: Foundation from `agents.md`)

- [ ] **Step 3: Commit**

```bash
git add docs/handoffs/
git commit -m "docs: generate session handoff via /handoff"
```

---

### Task 5: Register New Skills in `.opencode/config.json`

**Files:**
- Modify: `.opencode/config.json`

- [ ] **Step 1: Read current config**

```bash
cat .opencode/config.json
```

Navigate to the `"skills"` → `"coreSkills"` section (currently lines ~22-28).

- [ ] **Step 2: Add Matt Pocock skills to coreSkills array**

Current:
```json
"coreSkills": [
  "brainstorming",
  "test-driven-development",
  "systematic-debugging",
  "verification-before-completion",
  "receiving-code-review"
]
```

Updated:
```json
"coreSkills": [
  "brainstorming",
  "test-driven-development",
  "systematic-debugging",
  "verification-before-completion",
  "receiving-code-review",
  "tdd-workflow",
  "grill-with-docs",
  "handoff",
  "to-issues",
  "zoom-out"
]
```

Also add under `"projectSkills"` if desired for project-specific loading.

- [ ] **Step 3: Verify JSON is valid**

```bash
python3 -m json.tool .opencode/config.json > /dev/null && echo "Valid JSON" || echo "INVALID JSON"
```

Expected: `Valid JSON`

- [ ] **Step 4: Commit**

```bash
git add .opencode/config.json
git commit -m "config: register new skills (grill-with-docs, handoff, to-issues, zoom-out, tdd-workflow) in config.json"
```

---

### Task 6: End-to-End Pipeline Test — Triage Symptom Form (Skeleton)

**Files:**
- No code written. This task verifies the pipeline works before real development.
- Create: `docs/handoffs/` (a second handoff file from this test)

**Scenario:** Simulate starting the "build triage symptom form" feature from `agents.md` Phase 2.

- [ ] **Step 1: Open `docs/task-template.md`, fill in fields**

```markdown
# Task: Build Triage Symptom Form
## Stage: starting
## Context Dependencies
- [x] Load: agents.md
- [x] Load: backend/agents.md
- [x] Load: frontend/agents.md
## Pipeline
- [ ] 🧠 align → grill-with-docs → shared language + ADR
...
## Problem/Context
Need to build the patient symptom interview UI (React) + intake endpoint (Symfony).
```

Copy this filled template into your OpenCode session as the task prompt.

- [ ] **Step 2: Run `grill-with-docs`**

Invoke `grill-with-docs` on the symptom form feature. Expected: agent interviews you about the form flow (3-5 steps, symptom selection, AI analysis call, polling for results). Updates CONTEXT.md with form-specific terminology. Creates ADR if architectural decisions needed.

- [ ] **Step 3: Run `handoff` to save this test session**

```bash
/handoff
```

Expected: A second handoff file in `docs/handoffs/` documenting this test session. This is your proof the pipeline works end-to-end.

- [ ] **Step 4: Verify pipeline artifacts**

```bash
ls docs/handoffs/ && echo "---" && cat CONTEXT.md | wc -l && echo "lines in CONTEXT.md"
```

Expected:
- `docs/handoffs/` contains 2 files (setup session + test session)
- `CONTEXT.md` has grown (more domain terms added during grill-with-docs)
- Zero compilation errors (this was a dry run, no code)

- [ ] **Step 5: Commit**

```bash
git add docs/handoffs/ CONTEXT.md
git commit -m "test: verify full pipeline with grill-with-docs + handoff on symptom form feature"
```

---

### Task 7: Configure Docs-Repo (`.gitignore` + `raw_log.md`)

**Files:**
- Create: `.gitignore`
- Create: `raw_log.md`

**Repo purpose:** This is the project's "docs repo" — it tracks OpenCode config, docs, personal notes, and session files. `backend/` and `frontend/` have their own separate git repos and are excluded here.

- [ ] **Step 1: Write `.gitignore` for docs-repo layout**

```
# Separate repos (not tracked by this docs-repo)
backend/
frontend/

# Dependencies (from .opencode/)
.opencode/node_modules/

# Environment
.env
.env.local
.env.*.local

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db

# OpenCode temp files
.tmp/
```

What IS tracked by this repo:
- `.opencode/config.json`, `.opencode/skills/` (OpenCode configuration)
- `docs/` (documentation, ADRs, handoffs, plans, specs)
- `raw_log.md` (personal notes and thoughts)
- `agents.md` (master context) + any new context files
- OpenCode chat/session files (when they exist — e.g., `~/.opencode/sessions/` synced or `.opencode/sessions/`)

- [ ] **Step 2: Create `raw_log.md` with initial template**

```markdown
# TriageFlow — Raw Log

Personal notes, thoughts, and observations during development.

---

## 2026-05-26

- **Workflow setup**: Installed Matt Pocock skills, created task template + tools matrix
- **Repo layout**: triageflow root = docs repo (OpenCode config + docs), backend/ and frontend/ are separate repos
- **Next**: Start Phase 1 (Foundation) from agents.md

---
```

- [ ] **Step 3: Verify sensitive files excluded + correct files tracked**

```bash
git status --short
```

Expected: Only shows `.opencode/`, `docs/`, `agents.md`, `raw_log.md`, `.gitignore`. No `backend/` or `frontend/` files.

- [ ] **Step 4: Commit docs-repo structure**

```bash
git add .gitignore raw_log.md
git commit -m "chore: configure docs-repo (.gitignore excludes backend/frontend) + raw_log template"
```

---

## Completion Checklist

After all tasks complete, verify:

- [ ] `npx skills@latest add mattpocock/skills` ran successfully — 6 skills installed
- [ ] `/setup-matt-pocock-skills` configured repo (issue tracker, labels, docs path)
- [ ] `CONTEXT.md` exists with project domain terminology
- [ ] `docs/adr/2026-05-26-project-init.md` exists
- [ ] `docs/handoffs/` contains 2+ handoff files
- [ ] `.opencode/config.json` registers all new skills
- [ ] `.gitignore` excludes `backend/`, `frontend/`, and `node_modules/`
- [ ] `raw_log.md` created with template
- [ ] `git log --oneline` shows 6+ clean commits
- [ ] Full pipeline test passed: template → grill-with-docs → handoff
- [ ] `git status` shows only docs/config files (no backend/ or frontend/ tracked)

**On-demand tools** (`zoom-out`, `caveman`, `to-issues`) are not tested in this plan — they get exercised naturally during real development sessions. No setup task needed beyond installation.
