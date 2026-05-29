# Separate git repos for backend and frontend

Backend (`backend/`) and frontend (`frontend/`) each contain their own `.git` repository. They are not git submodules, not tracked by the docs repo, and not part of a monorepo tool (Nx, Turborepo, etc.).

The docs repo `.gitignore` excludes both directories:

```
backend/
frontend/
```

**Implications:**

- Each repo has its own commit history, branches, and remotes
- Commits must be staged and pushed separately per repo
- No shared git hooks or pre-commit checks across stacks
- CI/CD must be configured independently for `triageflow-backend` and `triageflow-frontend`

**Why:**

This keeps the PHP and Node dependency trees, tooling, and CI pipelines fully isolated. A monorepo was considered but rejected — Symfony and React have no shared tooling, and a 2-week portfolio project doesn't benefit from monorepo orchestration overhead.
