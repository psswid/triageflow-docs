# Handoff: OpenRouter Rate Limiter (Issue #12)

**Date:** 2026-06-16
**Backend repo:** `psswid/triageflow-backend`  
**Docs repo:** `psswid/triageflow-docs`  
**Issue:** `psswid/triageflow-docs#12` — Rate Limiter for OpenRouter (closed)

## Session Summary

Implemented `symfony/rate-limiter` across all 3 rate-limited endpoints (triage_submit 5/min, triage_answer 5/min, synthetic_generate 2/min) and added exponential backoff with Retry-After awareness to OpenRouterClient. 6 backend commits, 252 tests passing, PHPStan level 5 clean.

## What Changed

Full details in these artifacts instead of duplicating here:

| Artifact | Location |
|----------|----------|
| Session log | `raw_log.md` (entry: "2026-06-16 — Issue #12: OpenRouter Rate Limiter") |
| Implementation plan | `docs/superpowers/plans/2026-06-16-openrouter-rate-limiter.md` |

### In Brief

- **Symfony Rate Limiter**: 3 token bucket policies wired via `rate_limiter.yaml`. Controllers guard with 429 JSON:API response + rate limit headers.
- **OpenRouterClient backoff**: `parseRetryAfter()` (numeric + HTTP-date), `calculateBackoff()` (exponential + jitter + Retry-After cap 30s, -1 give-up signal). Fallback model 429s retry 3x instead of immediate throw.
- **Tests**: 10 new tests across 3 test files — controller 429 limits, per-user key isolation, Retry-After header parsing (numeric/HTTP-date/cap), missing header fallback.
- **Code review**: Fixed 1 critical (null dereference on `getResponse()`), 2 important (missing headers, hardcoded limits), 1 minor (Retry-After could be 0).

## Verification

| Check | Result |
|-------|--------|
| `php bin/phpunit` | ✅ 252/252 pass (893 assertions) |
| `php vendor/bin/phpstan analyse --level 5` | ✅ 0 errors |
| All 3 limiter services registered | ✅ `debug:container | grep limiter.` |
| Issue closed | ✅ `psswid/triageflow-docs#12` |

## Next Steps / Deferred

- **Frontend 429 handling**: Currently unhandled JSON parse error when backend returns 429. `useTriageInterview` and `useTriagePolling` need to detect `errors[0].code === 'RATE_LIMIT_EXCEEDED'` and show user-friendly message with Retry-After countdown.
- **Backend rate limiter before validation** (I-2 from code review): Rate limiter check currently happens after input validation. Attacker can waste validation work without consuming tokens. Low priority but architecturally wrong.
- **getUser() null guards** (I-1): All 5 TriageController endpoints call `$this->getUser()` without null check. Firewall protects today but defense-in-depth would add guard.

## Suggested Skills for Next Session

- **`brainstorming`** — Before designing the frontend 429 UX (countdown timer, auto-retry, toast alerts).
- **`ui-ux-pro-max`** — If implementing rate limit toast/alert UI patterns.
- **`handoff`** — To save another handoff when the frontend 429 handling work is complete.
