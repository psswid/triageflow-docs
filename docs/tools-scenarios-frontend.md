# TriageFlow — Frontend Scenarios

> React 19 + Vite + TanStack Query + Tailwind CSS + Vitest — every frontend scenario, every tool, every gate.
> Load `frontend/agents.md` before any frontend work.
> Origin tags: 🦸 Superpowers | 🧔 Matt Pocock | 🏠 Project (triageflow)

---

## Scenario F1: New Component

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find similar existing components, extract patterns | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define component purpose, props interface, states (loading/error/empty) | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | Component + co-located props interface, `readonly` props, Tailwind classes, dark mode | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Vitest + Testing Library: render, user interactions, accessibility, loading/error/empty states | `task(subagent="TestEngineer")` | 🦸 |
| 🔨 Build | Verify type check passes | `task(subagent="BuildAgent")` | 🦸 |
| 👁️ Review | Component patterns, accessibility, no `any`, dark mode coverage | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Tests pass, typecheck clean, works in dev server | `skill("verification-before-completion")` | 🦸 |

**Conventions:** Named exports only. `readonly` props. `useCallback`/`useMemo` for derived values. Loading/error/empty states always. `clsx` for conditional classes. Dark mode via `dark:` variants.

---

## Scenario F2: New Page + Route

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Check existing routes (`routes.tsx`), layouts, feature directories | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define route path, auth requirements, page role in user flow | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | Page component → Add route in `routes.tsx` → Lazy load if heavy → Wire TanStack Query hooks | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Routing test, auth guard, page content renders | `task(subagent="TestEngineer")` | 🦸 |
| 🔭 Context | See how page fits feature flow and navigation | `skill("zoom-out")` | 🧔 |
| 👁️ Review | Route naming, auth protection, lazy loading | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Navigate in dev, auth works, back button behaves | `skill("verification-before-completion")` | 🦸 |

**Conventions:** `createBrowserRouter` in `routes.tsx`. Protected routes via wrapper component. Feature-based directory (`features/{name}/pages/`). Error boundary at feature level.

---

## Scenario F3: API Integration (TanStack Query)

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch current TanStack Query docs (Query + Mutation patterns) | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Find existing hooks in `api/hooks.ts`, API types in `api/types.ts` | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define query key, refetch strategy, mutation side effects | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | Query hook (`useQuery`) or Mutation hook (`useMutation`) with `queryClient.invalidateQueries` | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Mock `apiClient`, test loading/error/success states, polling logic | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Cache invalidation correctness, optimistic updates safe, polling interval appropriate | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | API calls work, cache invalidates, polling stops when done | `skill("verification-before-completion")` | 🦸 |

**Conventions:** Single `apiClient` instance. TanStack Query for all GETs. Mutations for POST/PUT/PATCH. `refetchInterval` for async polling (triage results). JWT interceptor handles auth.

---

## Scenario F4: Feature — Triage Interview

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch React 19 docs (new APIs, form patterns) | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Check existing triage feature structure, shared components | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define interview flow (step count, symptom selection, polling UX, result display) | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | Multi-step form, submit, polling → result card — parallel batches for components | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🎫 Issues | Plan → independently-grabbable GitHub issues | `skill("to-issues")` | 🧔 |
| 🔨 Implement | `SymptomForm` → `ProgressBar` → `useTriage` hook → `useSubmitTriage` mutation → `TriageResultPage` + `ResultCard` with polling | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🎨 Design | Urgency-colored cards, step progress, loading animations | `task(subagent="OpenFrontendSpecialist")` (optional) | 🦸 |
| 🔭 Context | Verify triage flow matches backend API contract | `skill("zoom-out")` | 🧔 |
| 🧪 Test | Component tests (form, polling, result) + Integration (full interview flow) | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | UX flow, accessibility, error states, dark mode | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Full interview works end-to-end, polls correctly, dark mode looks good | `skill("verification-before-completion")` | 🦸 |

**Key patterns:** Multi-step form with progress bar. Submit → 202 → poll `/api/triage/status/{id}` every 2s. Result card color-coded by urgency. Loading skeleton during AI processing.

---

## Scenario F5: Feature — Admin Dashboard

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find existing admin features, shared components (Card, Table, StatsGrid) | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define dashboard layout (stats grid → submissions table → detail view) | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | StatsGrid, SubmissionsTable, SubmissionDetail — parallel if independent | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🔨 Implement | `useAdminStats` query → `StatsGrid` → `useSubmissions` query → `SubmissionsTable` → `SubmissionDetailPage` | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🧪 Test | Component tests + integration (dashboard loads, table paginates, detail renders) | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Data freshness, empty states, responsive layout, auth protection | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Dashboard loads with data, filters work, detail view shows full submission | `skill("verification-before-completion")` | 🦸 |

---

## Scenario F6: Component Refactor

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Map | Find all usages, imports, dependents of target component | `task(subagent="ContextScout")` + `task(subagent="explore")` | 🦸 |
| 🧪 Baseline | Run test suite, capture snapshot | `bash: npm run test -- --reporter=verbose` | — |
| 📋 Plan | Extract what? Rename what? Merge/split? | Quick verbal plan | — |
| 🔨 Refactor | Incremental: extract UI primitives, rename, consolidate — green after each step | `task(subagent="CoderAgent")` | 🦸 |
| 🔭 Context | Verify refactored component still fits feature patterns | `skill("zoom-out")` | 🧔 |
| 👁️ Review | Patterns improved, no regressions, same behavior preserved | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Identical test results pre/post, typecheck clean | `skill("verification-before-completion")` | 🦸 |

---

## Scenario F7: Tailwind Design Change

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch Tailwind CSS 4 docs (new APIs, breaking changes) | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Find all components using the pattern to change, check `design-system.css` | `task(subagent="ContextScout")` | 🦸 |
| 🎨 Design | Propose new tokens/colors, visual before/after | `task(subagent="OpenFrontendSpecialist")` | 🦸 |
| 🔨 Implement | Update `tailwind.config.ts` tokens → `design-system.css` classes → component `className` updates | `task(subagent="CoderAgent")` | 🦸 |
| 🔨 Build | Verify build with new styles | `task(subagent="BuildAgent")` | 🦸 |
| 👁️ Review | Dark mode coverage, contrast (WCAG AA), responsive breakpoints, no broken layouts | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Visual check in dev, dark mode toggle works, mobile-first responsive | `skill("verification-before-completion")` | 🦸 |

**Design tokens:** `urgency.low/medium/high/emergency` colors. `primary` palette. `dark:` variants everywhere. `clsx` for conditional classes.

---

## Scenario F8: Frontend Debugging

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🐛 Reproduce | Isolate: component render, API call, type error | Manual + `bash: npm run test -- -t "failing test"` | — |
| 🔍 Diagnose | Root cause analysis (React devtools, network tab, console) | `skill("systematic-debugging")` | 🦸 |
| 🔎 Explore | Find related components, hooks, types | `task(subagent="explore")` (quick → very thorough) | 🦸 |
| 🔭 Context | Understand affected feature in full flow | `skill("zoom-out")` | 🧔 |
| 🔨 Fix | Red → green → refactor | `skill("tdd-workflow")` | 🦸 |
| 👁️ Review | Fix correctness, no regression, type safety preserved | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Bug gone, full suite passes, typecheck clean | `skill("verification-before-completion")` | 🦸 |

**Debug tools:** React DevTools. Network tab (check API calls, JWT). `tsc --noEmit`. `npm run test -- --reporter=verbose --reporter=@vitest/verbose-reporter`.

---

## Frontend Quick Reference

```
New component?        → context-scout → grill-with-docs → tdd → test-engineer → build → review → verify
New page?             → context-scout → grill-with-docs → tdd → test-engineer → zoom-out → review → verify
API integration?      → external-scout → context-scout → grill-with-docs → coder → test-engineer → review → verify
Triage feature?       → external-scout → context-scout → grill-with-docs → write-plan → to-issues → tdd (batches) → (frontend-specialist) → zoom-out → tests → review → verify
Admin dashboard?      → context-scout → grill-with-docs → write-plan → tdd (batches) → tests → review → verify
Refactor?             → context-scout → explore → baseline-tests → coder → zoom-out → review → verify
Design change?        → external-scout → context-scout → frontend-specialist → coder → build → review → verify
Debugging?            → systematic-debugging → explore → zoom-out → tdd → review → verify
```

**Cross-reference:** Backend scenarios → `docs/tools-scenarios-backend.md` | Master reference → `docs/tools-scenarios-matrix.md`
