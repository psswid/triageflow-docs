# Handoff: CI Pipeline — GitHub Actions Workflows [COMPLETE]

## State

Both backend and frontend CI workflows are created, pushed, and passing. Frontend CI passed on first push. Backend CI required 5 iterations / 8 fixes across 4 commits.

## What Was Done

### CI workflow files

| Repo | File | Jobs |
|------|------|------|
| `triageflow-backend` | `.github/workflows/ci.yml` | tests (228 PHPUnit + PostgreSQL service), static-analysis (PHPStan level 5), docker-build (`docker compose build`) |
| `triageflow-frontend` | `.github/workflows/ci.yml` | tests (Vitest 87 tests), typecheck (`tsc --noEmit`) |

### Backend CI fixes (4 commits on `psswid/triageflow-backend`)

| Commit | Fix | Root Cause |
|--------|-----|------------|
| `c9f7bf2` | `JWT_PASSPHRASE=` (empty) | OpenSSL 3.x rejects non-empty passphrase on unencrypted PKCS#8 key (`DECODER routines::unsupported`) |
| `ac98b87` | `openssl genpkey` in CI step | JWT keys not tracked in git — don't exist in checkout |
| `d6084c7` | `Length(min: 8)` named args | Symfony 7.3 deprecation triggers `failOnDeprecation="true"` |
| `bb36395` | `coverage: pcov` (was `none`) | "No coverage driver" warning triggers `failOnWarning="true"` |

### Key details

- **`.env` handling**: `.env` not in git → created from `.env.test` + appended env vars (`DEFAULT_URI`, `CORS_ALLOW_ORIGIN`, `MESSENGER_TRANSPORT_DSN`, `MAILER_DSN`, `JWT_*`) needed at runtime but absent from `.env.test`
- **Composer**: `--no-scripts` to skip `cache:clear` which needs `.env`; `.env` created after `composer install`
- **JWT keys**: Generated at runtime via `mkdir -p config/jwt && openssl genpkey -algorithm RSA -out config/jwt/private.pem && openssl pkey -in config/jwt/private.pem -pubout -out config/jwt/public.pem`
- **PostgreSQL**: CI service container `postgres:16-alpine` with health check

## Current Project State

| Criterion | Result |
|-----------|--------|
| `psswid/triageflow-backend` CI | ✅ All 3 jobs green |
| `psswid/triageflow-frontend` CI | ✅ All 2 jobs green |
| Backend tests | 228 tests, 771 assertions, 0 failures |
| PHPStan level 5 | 0 errors |
| Frontend tests | 87 tests, 0 failures |

## Known Issues

- **Node.js 20 deprecation**: `actions/checkout@v4` and `actions/cache@v4` run on Node.js 20, deprecated June 16, 2026. Will need bumping to v5 variants by September 2026.
- **No E2E CI**: Playwright tests exist but aren't wired into CI. The E2E setup needs Playwright browsers installed on the runner.

## Artifacts

- **ADR-0007** (`docs/adr/0007-ci-runtime-jwt-keys.md`) — Documents the decision to generate JWT keys at runtime in CI rather than committing them.
- **CI workflow files**: `backend/.github/workflows/ci.yml` and the frontend equivalent (in its own repo).
- **`raw_log.md`** — Full CI pipeline entry with all 5 iterations documented.

## Suggested Skills

- `verification-before-completion` — verify CI status before claiming completion
- `systematic-debugging` — for any future CI failures
- `docker-patterns` — for Docker-related CI concerns
