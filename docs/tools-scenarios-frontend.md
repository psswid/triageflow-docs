# TriageFlow — Frontend Scenarios

> React 19 + Vite + TanStack Query + Tailwind CSS + Vitest — every frontend scenario, every tool, every gate.
> Load `frontend/agents.md` before any frontend work.
> Origin tags: 🦸 Superpowers | 🧔 Matt Pocock | 🏠 Project (triageflow)

---

## Scenario F1: New Component

**When:** Building a reusable UI piece — button variant, card, input, or shared composite like a `Loader` or `EmptyState`.
**Success:** Typed props (`readonly`), all states covered (loading/error/empty/happy), dark mode via `dark:`, accessible (focus, labels, roles), tested with Vitest + Testing Library.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find similar existing components in `components/ui/` or `components/shared/`. Extract the patterns: how are props typed, how is `clsx` used for variants, what's the dark mode pattern | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define component purpose, props interface (every prop `readonly`), and the three states every component MUST handle: loading (skeleton/spinner), empty ("No items yet"), error (red banner with retry button). Write this into the task template so the agent has explicit instructions | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | Named export function component. Co-located props interface with `readonly` on every prop. `useCallback` for handlers passed to children. `clsx` for conditional Tailwind classes (never string concatenation). Dark mode via `dark:` variants. Error boundary wrapper if the component does async work | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | **Render test:** Component renders with given props. **Interaction test:** Click handler fires, state toggles. **Loading state:** Shows skeleton/spinner when `isLoading={true}`. **Empty state:** Shows "No items" when data is empty array. **Error state:** Shows error message when `error` prop is set. **Accessibility:** Button has accessible name, focus ring visible, color contrast passes. **Dark mode:** Component renders correctly with dark mode classes | `task(subagent="TestEngineer")` | 🦸 |
| 🔨 Build | TypeScript strict mode check — no `any`, no missing types, no `as` casts without type guards | `task(subagent="BuildAgent")` | 🦸 |
| 👁️ Review | Named export (not default). All props `readonly`. No `any`. All three states handled. `clsx` used correctly. `dark:` variants present on all color/background classes | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | All tests green. `tsc --noEmit` passes. Component renders in dev server. Dark mode toggle works. Keyboard navigable | `skill("verification-before-completion")` | 🦸 |

**Conventions:** Named exports only (`export function Button` not `export default`). `readonly` on all props. `useCallback`/`useMemo` for derived values and handlers passed to children. Loading/error/empty states for EVERY async component. `clsx` for conditional classes. Dark mode via `dark:` variants. WCAG AA minimum.

**⚠️ Watch out:** The most common component mistake is skipping states. A component that looks fine with data crashes when `data` is `undefined` during loading. Always design for loading → empty → error → data states. Also: `clsx` not string concatenation — `className={'bg-blue-500 ' + (isActive ? 'ring' : '')}` breaks Tailwind's purging.

---

## Scenario F2: New Page + Route

**When:** Adding a new page to the app — triage result view, admin detail page, settings page.
**Success:** Route defined in `createBrowserRouter`, page component follows feature-directory pattern, auth protection if needed, lazy-loaded if large.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Check `routes.tsx` for existing route patterns. Check which layout this page belongs under (`AppLayout` for public, `ProtectedRoute` wrapper for admin). Check feature directory structure for similar pages | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define route path (kebab-case, descriptive), auth requirements (public / protected / admin-only), and whether the page needs lazy loading (check `npm run build` output — if page chunk >50KB, use `React.lazy`) | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | **Step 1:** Create page component in `features/{name}/pages/{PageName}.tsx`. **Step 2:** Add route to `routes.tsx` as child of correct layout. **Step 3:** If protected, wrap in `<ProtectedRoute />` with role check. **Step 4:** If large, wrap import in `React.lazy(() => import(...))` with `<Suspense fallback={<PageLoader />}>`. **Step 5:** Wire TanStack Query hooks in the page component (data fetching happens at page level, not component level) | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | **Routing test:** Navigate to route, assert page renders. **Auth guard test:** Unauthenticated → redirected to login. Wrong role → 403 or redirect. **Page content test:** Page loads data, displays correct components | `task(subagent="TestEngineer")` | 🦸 |
| 🔭 Context | Zoom out: does this page fit the navigation flow? Can the user reach it naturally? Does the back button go somewhere sensible? Is the route discoverable? | `skill("zoom-out")` | 🧔 |
| 👁️ Review | Route path follows convention. Lazy loading configured for large pages. Auth protection tested. Error boundary present at feature level. Breadcrumbs/sidebar updated if needed | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Navigate to page in dev. Refresh — page still works (not a SPA-only URL). Auth gating works. Back button returns to previous page. Lazy loaded chunk appears in Network tab on first visit | `skill("verification-before-completion")` | 🦸 |

**Conventions:** `createBrowserRouter` in `routes.tsx`. Protected routes via `<ProtectedRoute>` wrapper component. Feature-based directory (`features/{name}/pages/`). `ErrorBoundary` at feature level (not per component). Lazy loading via `React.lazy` + `Suspense` for pages >50KB.

**⚠️ Watch out:** React Router 7 uses `createBrowserRouter` (not `<BrowserRouter>` JSX). If you mix old and new patterns, routing silently breaks. Also: lazy-loaded routes need an `<ErrorBoundary>` — if the chunk fails to load (network error), the error boundary catches it instead of a white screen.

---

## Scenario F3: API Integration (TanStack Query)

**When:** Connecting to a new or existing API endpoint — GET for data display, POST/PUT/PATCH for mutations.
**Success:** Hook defined in `api/hooks.ts`, query key unique and descriptive, refetch strategy correct (polling for async endpoints), cache invalidation after mutations, JWT handled by interceptor.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch current TanStack Query v5 docs — API changes from v4, `useQuery`/`useMutation` signatures, `queryClient.invalidateQueries` patterns, optimistic update patterns | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Find existing hooks in `api/hooks.ts` to follow the established pattern. Check `api/types.ts` for existing API response types. Check `api/client.ts` for the axios instance and interceptor setup | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define: query key (array, descriptive — e.g., `['triage', id]` not `['data']`), refetch strategy (default stale time? polling interval for async endpoints?), mutation side effects (invalidate which queries? optimistic update possible?) | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | **Query hook:** `useQuery({ queryKey: ['resource', id], queryFn: () => apiClient.get<T>(url), refetchInterval: pollingCondition ? 2000 : false })`. **Mutation hook:** `useMutation({ mutationFn: (data) => apiClient.post(url, data), onSuccess: () => queryClient.invalidateQueries({ queryKey: ['resource'] }) })`. Add response type to `api/types.ts` if new. Keep hooks in `features/{name}/hooks/` if feature-specific, `api/hooks.ts` if shared | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | **Query test:** Mock `apiClient.get` with `vi.mock()`, test loading state (returns `isLoading: true`), success state (returns data), error state (returns `isError: true`). **Mutation test:** Mock `apiClient.post`, test `onSuccess` callback fires, test `onError` callback fires. **Polling test:** Mock timer, advance by interval, assert refetch happens. **Cache test:** After mutation, assert related query refetches | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Query key is unique and descriptive. `refetchInterval` stops when not needed (e.g., stops polling when status is not 'processing'). Cache invalidation targets correct queries (not too broad, not too narrow). Optimistic updates don't cause flicker. Error handling present (not just `console.error` — show user feedback) | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Hook returns data correctly. Loading state appears while fetching. Error state shows user-friendly message. Polling starts/stops correctly. Mutation invalidates cache → UI updates. Network tab shows correct API calls | `skill("verification-before-completion")` | 🦸 |

**Conventions:** Single `apiClient` instance (axios with JWT interceptor). TanStack Query for all GET requests. TanStack Query mutations for POST/PUT/PATCH. `refetchInterval` for async polling (triage results poll every 2s while processing). `queryClient.invalidateQueries` on mutation success. Error handling in interceptor (401 → clear JWT + redirect).

**⚠️ Watch out:** Query keys are how TanStack Query knows what to cache and invalidate. `['triage', id]` and `['triage', 'list']` are different caches — use consistent key structures. Also: polling with `refetchInterval` must stop — check the query data and return `false` when polling is no longer needed. Infinite polling wastes bandwidth and API calls.

---

## Scenario F4: Feature — Triage Interview

**When:** Building the core patient triage flow — the main feature of the application.
**Success:** Multi-step symptom selection form, submit triggers async AI processing, UI polls for result, result card color-coded by urgency with specialist recommendation and justification.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch React 19 docs — new form APIs (`useActionState`, `useFormStatus`), any changes to controlled components, `startTransition` patterns. Also TanStack Query docs for polling best practices | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Check existing triage feature structure (`features/triage/`). Find shared components you can reuse (Button, Card, ProgressBar). Check the backend API contract: POST `/api/triage/submit` (returns 202 + status URL), GET `/api/triage/status/{id}` (returns pending/processing/completed/failed), GET `/api/triage/result/{id}` (returns final result) | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Design the interview flow: How many steps? What's the UX for symptom selection (buttons? search? categories?)? What does the user see while AI is processing (skeleton? progress animation? estimated time?)? How is the result presented (color-coded by urgency, specialist badge, justification text)? Write this into `CONTEXT.md` — this is the UX spec the agent follows | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | Break into parallel-capable subtasks: `SymptomForm` (step component) + `ProgressBar` (shared) + `useTriage` hook (polling) + `useSubmitTriage` mutation + `TriageResultPage` + `ResultCard` (urgency-colored) + `LoadingSkeleton` (shared). TaskManager identifies dependencies: form → submit → poll → result is sequential, but UI primitives (ProgressBar, ResultCard, LoadingSkeleton) can be built in parallel | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🎫 Issues | Convert plan to GitHub issues — one per vertical slice so work is independently grabbable | `skill("to-issues")` | 🧔 |
| 🔨 Implement | Execute in dependency order. Batch 1 (parallel): `ProgressBar`, `ResultCard`, `LoadingSkeleton`, API types. Batch 2 (sequential, depends on Batch 1 + API types): `SymptomForm`, `useTriage` hook, `useSubmitTriage` mutation. Batch 3 (sequential, depends on Batch 2): `TriagePage` (wires form + submit), `TriageResultPage` (wires polling + result card). Each batch: tdd-workflow → CoderAgent → tests must pass before proceeding | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🎨 Design | Urgency color system: LOW=green, MEDIUM=yellow, HIGH=orange, EMERGENCY=red. Step progress bar with current/total. Loading skeleton with pulse animation during AI processing. Result card with urgency-colored border + specialist icon + justification text | `task(subagent="OpenFrontendSpecialist")` (optional — for polish) | 🦸 |
| 🔭 Context | Verify entire flow matches backend API contract. Check: does the form send exact shape backend expects? Does polling use correct URL from 202 response? Does result page handle all statuses (processing, completed, failed)? Does the UI handle the "no result yet" state while polling? | `skill("zoom-out")` | 🧔 |
| 🧪 Test | **SymptomForm:** Select/deselect symptoms, submit with empty selection (disabled button). **useSubmitTriage:** Mutation fires on submit, 202 response, status URL stored. **useTriage polling:** Polls every 2s while status=processing, stops when completed or failed. **ResultCard:** Each urgency level renders correct color, specialist displayed with label, justification text visible. **Integration:** Full flow — select symptoms → submit → poll → result displayed. **Error flow:** Submit fails → error message shown. AI fails → result page shows "Analysis failed" state | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Form accessibility (keyboard navigable, screen reader labels). Polling stops when complete. Loading state not jarring (smooth transition). Error states recoverable (retry button). Dark mode renders correctly at every step. Mobile responsive (form works on phone screens) | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Full flow works end-to-end in dev. Polling interval appropriate. Error states tested. Dark mode looks good. Mobile responsive. All tests pass. Type check clean | `skill("verification-before-completion")` | 🦸 |

**Key patterns:** Multi-step form with progress bar (step N of M). Submit → 202 Accepted with `Location` header → poll `GET /api/triage/status/{id}` every 2 seconds → `refetchInterval` returns `false` when status is `completed` or `failed`. Result card border/icon colored by urgency enum. Loading skeleton with `animate-pulse` during AI processing.

**⚠️ Watch out:** The polling loop is the trickiest part. If you forget to stop polling when the result is ready, you'll hammer the API forever. The `refetchInterval` function must check `query.state.data?.status` and return `false` when done. Also: handle the "AI processing failed" state — the result endpoint returns `status: 'failed'` with an error message. Don't leave the user staring at a spinner forever.

---

## Scenario F5: Feature — Admin Dashboard

**When:** Building the admin panel — submission overview, filtering, detail drill-down.
**Success:** Stats grid with key metrics, submissions table with pagination/sorting/filtering, detail page with full submission + AI analysis.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find existing admin components in `features/admin/`. Check shared components: `Card` (for stats), `EmptyState` (for no results), `Loader` (for loading state). Check backend admin API: `GET /api/admin/submissions`, `GET /api/admin/submissions/{id}`, `GET /api/admin/stats` | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define dashboard layout: top row = stats grid (total submissions, by urgency, by specialist, synthetic vs real), main area = submissions table with filter bar (by status, urgency, date range), detail view = slide-out panel or separate page | `skill("grill-with-docs")` | 🧔 |
| 📋 Plan | Parallel batches: StatsGrid (uses stats API) + SubmissionsTable (uses submissions API with filters) can be built simultaneously. SubmissionDetail depends on table (needs the ID from a row click) | `skill("writing-plans")` → `task(subagent="TaskManager")` | 🦸 |
| 🔨 Implement | `useAdminStats` query hook → `StatsGrid` component (4 cards: total, by urgency, by specialist, synthetic count). `useSubmissions` query with filter params → `SubmissionsTable` (sortable columns, filter dropdowns, pagination). `SubmissionDetailPage` or slide-over (full submission data + AI raw response toggle). Lazy load detail view (it can be heavy) | `skill("tdd-workflow")` → `task(subagent="CoderAgent")` per batch | 🦸 |
| 🧪 Test | Stats render with mock data. Table renders rows, pagination works, filters update query params. Detail renders full submission. Empty state when no submissions. Loading skeleton while fetching. Error state when API fails | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Data freshness — are stats stale? Should they auto-refetch? Empty states present for every list. Responsive layout (table scrolls horizontally on mobile). Auth protection (admin only). Synthetic submissions visually distinguished (badge/indicator) | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Dashboard loads with data. Filters work. Pagination works. Detail view shows full submission. Refresh updates data. Synthetic submissions marked. Dark mode renders correctly | `skill("verification-before-completion")` | 🦸 |

---

## Scenario F6: Component Refactor

**When:** Extracting a reusable piece from a page, renaming for clarity, splitting a large component, or consolidating duplicated patterns.
**Success:** Same behavior, better structure, zero regressions, typecheck passes, patterns are more consistent.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Map | Find all usages, imports, and dependents of the target component. `grep` for imports, check for test files that reference it, check if any snapshot tests will break | `task(subagent="ContextScout")` + `task(subagent="explore")` | 🦸 |
| 🧪 Baseline | Run full test suite, save the output. This is your safety net — any behavior change will show as a test diff | `bash: npm run test -- --reporter=verbose > /tmp/before-refactor.txt` | — |
| 📋 Plan | Decide: extract what to where? Rename to what? Merge which into which? Split where? Document the plan in 2-3 bullets so the agent knows exactly what to do | Quick verbal plan (2-3 bullets) | — |
| 🔨 Refactor | Execute incrementally. One change at a time. Run tests after each change — if they break, you know exactly which change caused it. Extract → rename → consolidate → remove duplicates. Use CoderAgent for larger refactors (4+ files), direct for single-file | `task(subagent="CoderAgent")` (if >3 files affected) | 🦸 |
| 🔭 Context | After refactoring, zoom out: are the extracted components truly reusable? Do the new names accurately describe what they do? Is the file structure logical for someone seeing it for the first time? | `skill("zoom-out")` | 🧔 |
| 👁️ Review | Patterns improved (not just moved). No new patterns introduced that contradict conventions. All old imports updated (no stale references). No dead code left behind | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Test output identical to baseline (same number of tests, same pass/fail). Typecheck clean. Dev server renders correctly. No console errors. No new lint warnings | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** Renaming a component but forgetting to update a lazy-loaded import (`React.lazy(() => import('./OldName'))`) will break at runtime, not compile time. Use `grep` exhaustively. Also: don't extract prematurely. A component used in one place doesn't need to be "reusable." Extract when you find the second usage or when the file is genuinely too large (>300 lines).

---

## Scenario F7: Tailwind Design Change

**When:** Updating the design system — new color palette, spacing scale, typography, component variants, or dark mode overhaul.
**Success:** Design tokens updated in `tailwind.config.ts`, components use new tokens consistently, dark mode renders correctly, WCAG AA contrast met, build passes.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch Tailwind CSS 4 docs — v4 has breaking changes from v3 (CSS-based config, `@theme` directive, new utility names). Make sure you're using the correct API for the installed version | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Find all components using the pattern to change. Search for the old color class, old spacing value, old component variant. Check `design-system.css` for custom classes that need updating | `task(subagent="ContextScout")` | 🦸 |
| 🎨 Design | Propose new tokens: colors (light + dark), spacing/sizing, typography scale. Show before/after of key components. Get visual sign-off before implementing | `task(subagent="OpenFrontendSpecialist")` | 🦸 |
| 🔨 Implement | **Step 1:** Update `tailwind.config.ts` — new color tokens, dark mode settings, breakpoints. **Step 2:** Update `design-system.css` — custom utility classes using new tokens. **Step 3:** Update all component `className` strings — replace old utility classes with new ones. Use find-and-replace with care (verify each change visually). **Step 4:** Update dark mode variants — ensure every component has `dark:` counterpart for new colors | `task(subagent="CoderAgent")` | 🦸 |
| 🔨 Build | Vite build — Tailwind purges unused classes, build output shows CSS size. If build fails, a class reference is broken | `task(subagent="BuildAgent")` | 🦸 |
| 👁️ Review | Every color has a `dark:` variant. Contrast ratios meet WCAG AA (4.5:1 for text, 3:1 for large text/UI). Responsive breakpoints still work. No hardcoded colors outside Tailwind (check for `style={{color: '#xxx'}}`) | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Visual check: every page, light mode, dark mode. Responsive: mobile, tablet, desktop. Accessibility: run axe DevTools or Lighthouse. No visual regressions | `skill("verification-before-completion")` | 🦸 |

**Design tokens:** `urgency.low` (green), `urgency.medium` (yellow), `urgency.high` (orange), `urgency.emergency` (red). `primary` palette. `dark:` variants on every color property. `clsx` for conditional classes. Custom classes in `design-system.css` for repeated patterns.

**⚠️ Watch out:** Tailwind v4 moved from `tailwind.config.js` to CSS-based config with `@theme`. If you're on v4, the config file pattern is different. Check `package.json` for the installed version before making config changes. Also: a global find-and-replace on class names is dangerous — `bg-red-500` might be a button color you want to change AND an error state you don't. Audit each change.

---

## Scenario F8: Frontend Debugging

**When:** Component doesn't render, API call fails silently, type error, "works on my machine," or visual bug.
**Success:** Bug reproduced in a test, root cause found, fix applied with test proving it, no regression.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🐛 Reproduce | Isolate the failure to the smallest possible reproduction. Write a failing Vitest test that captures the bug. For visual bugs: screenshot + description. For API bugs: capture network tab (request payload, response, status) | Manual + `bash: npm run test -- -t "failing test"` | — |
| 🔍 Diagnose | Use `systematic-debugging`: is it a render issue (component doesn't mount), a data issue (API returns unexpected shape), a type issue (runtime vs compile-time mismatch), or a styling issue (CSS specificity, missing Tailwind class)? Use React DevTools to inspect component tree + props. Use Network tab to verify API calls | `skill("systematic-debugging")` | 🦸 |
| 🔎 Explore | Find related components, hooks, and types. Check if the buggy pattern is used elsewhere (and also broken). Search for similar API call patterns, similar component compositions | `task(subagent="explore")` (quick → very thorough as needed) | 🦸 |
| 🔭 Context | Understand the feature's full user flow. Could the bug be in a parent component's state that affects this child? Could it be a TanStack Query cache issue (stale data)? | `skill("zoom-out")` | 🧔 |
| 🔨 Fix | Write the failing test first. Run it — it should fail (proving you captured the bug). Implement the fix. Run that single test — green. Run full suite — still green. If the fix changes behavior that other tests relied on, update those tests | `skill("tdd-workflow")` | 🦸 |
| 👁️ Review | Fix is minimal. No new TypeScript errors. No new lint warnings. The same bug pattern fixed elsewhere if found | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Original bug is gone (test proves it). Full test suite passes. Typecheck clean. Manual check in dev: component renders, API call works, visual bug fixed | `skill("verification-before-completion")` | 🦸 |

**Debug tools:** React DevTools (component tree, props, state). Browser DevTools: Network tab (API calls, JWT header), Console (errors, warnings), Elements (computed styles). `tsc --noEmit` for type errors. `npm run test -- --reporter=verbose` for detailed test output.

**⚠️ Watch out:** The most insidious frontend bugs are the ones TypeScript can't catch. An API response that's missing a field that your type says is required — TypeScript says it's fine (the type is a lie), but the component crashes at runtime. Always validate API responses at the boundary (use zod or manual checks). Also: TanStack Query cached data can make a fix appear not to work — clear the cache or check `staleTime` settings.

---

## Scenario F9: Authentication Flow

**When:** Building login/logout, JWT storage, protected routes, or token refresh logic.
**Success:** Login form submits credentials, stores JWT in localStorage, interceptor attaches token to all API calls, ProtectedRoute redirects unauthenticated users, logout clears token and redirects.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch current React Router v7 docs for route protection patterns (`loader` functions, `redirect`). Fetch axios interceptor docs for request/response hooks | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Survey | Check existing auth code: `useAuth` hook, `api/client.ts` interceptors, `routes.tsx` protected routes, `components/layout/` for auth-aware UI (login/logout button, user menu) | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define auth flow: login page (public) → submit credentials → receive JWT + refresh token → store in localStorage → redirect to dashboard. Protected routes: check token exists (not expired check — let the API 401 handle that) → if no token, redirect to `/login` with `?redirect=` param. Logout: clear localStorage → redirect to login | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | **Login form:** `LoginPage` with email/password form, `useLogin` mutation (calls `POST /api/login`), on success: `localStorage.setItem('jwt_token', token)`, redirect. **Interceptor:** Already configured in `api/client.ts` — verify it reads from localStorage. **ProtectedRoute:** Wrapper component — check `localStorage.getItem('jwt_token')`, if missing → `<Navigate to="/login" />`. **UserContext:** React Context with user info, loaded after login via `GET /api/me`. **Logout:** Clear localStorage, `queryClient.clear()`, redirect | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Login form renders. Submit with valid credentials → JWT stored, redirect happens. Submit with invalid credentials → error message shown. Protected route without token → redirected to login. Protected route with token → page renders. Logout → token cleared, redirected. API interceptor attaches token to requests. 401 response → interceptor clears token + redirects | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | Token in localStorage (not sessionStorage — persists across tabs). No token in URL. Redirect preserves intended destination (`?redirect=`). Logout clears everything (token, user context, query cache). Login form has CSRF protection if using session auth | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Full login flow works. Protected routes block unauthenticated access. Token refresh works (or at least 401 redirects gracefully). Logout cleans up completely. Multiple tabs stay in sync (or at least don't break) | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** localStorage JWT is vulnerable to XSS. For a portfolio project this is acceptable, but know the tradeoff. Never store refresh tokens in localStorage (use httpOnly cookies for those). Also: the axios response interceptor that redirects on 401 must not redirect on the login endpoint itself (or you get a redirect loop). Check `error.config.url` before redirecting.

---

## Scenario F10: Error Handling & Boundaries

**When:** Adding error boundaries, improving API error display, handling network failures gracefully, or building retry UX.
**Success:** No white screens on error. Error boundaries catch render failures and show fallback UI. API errors display user-friendly messages (not raw error objects). Network failures show "offline" state with retry.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Find current error handling: is there an `ErrorBoundary` component? Are API errors caught and displayed? What happens when the network is offline? What happens when a React component throws during render? | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Define error strategy: **Render errors** → ErrorBoundary catches, shows "Something went wrong" + retry button. **API errors** → Each TanStack Query hook uses `isError` + `error` to show inline error message with retry. **Network errors** → Global online/offline detection via `navigator.onLine` + `window.addEventListener('online'/'offline')` — show banner "You're offline." **404s** → Dedicated NotFound page | `skill("grill-with-docs")` | 🧔 |
| 🔨 Implement | **ErrorBoundary:** Class component with `componentDidCatch` + `getDerivedStateFromError`, fallback UI with error message + "Try again" button (calls `location.reload()`). Place at feature level in `routes.tsx` errorElement. **API error display:** Each component using a query — render `if (isError)` → `<ErrorBanner message={error.message} onRetry={refetch} />`. **Offline banner:** Hook `useOnlineStatus` that returns boolean — render `<OfflineBanner />` when offline. **NotFound:** Route with `path: '*'` → `<NotFoundPage />` | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | ErrorBoundary catches render error → fallback renders. API error state displays message + retry button → retry calls `refetch`. Offline banner appears when `navigator.onLine` is false. 404 route renders NotFound page | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | No raw error objects in UI. Error messages are user-friendly. Retry buttons wired correctly. Offline detection works. ErrorBoundary placement is strategic (feature level, not per component) | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Trigger render error (throw in component) → fallback shows. Trigger API error (mock server returns 500) → error message shows. Go offline → banner appears, API calls show "offline" message. Go back online → banner disappears | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** Error boundaries only catch errors during rendering — not errors in event handlers, async code, or setTimeout. You still need try/catch for those. Also: don't wrap every component in its own ErrorBoundary — one per route/feature is the right granularity. Too many boundaries means users see mini-error states everywhere instead of one clean fallback.

---

## Scenario F11: Testing Strategy

**When:** Setting up testing for a new feature, deciding test types, or improving coverage.
**Success:** Component tests for UI logic, integration tests for user flows, MSW for API mocking, E2E tests for critical paths. All three Async states (loading/error/success) tested per component. 80%+ coverage.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Survey | Check `vitest.config.ts` setup, existing test patterns in `*.test.tsx` files, MSW setup (`src/mocks/`), and coverage report (`npm run test -- --coverage`) | `task(subagent="ContextScout")` | 🦸 |
| 🧠 Align | Decide test types for this feature: **Component tests** (fast, no API — mock hooks). **Integration tests** (real components + mocked API via MSW). **E2E tests** (Playwright/Cypress — full browser, real API, for critical flows: triage submit, admin login) | `skill("grill-with-docs")` | 🧔 |
| 🔨 Write | **Component test template:** render component, assert loading state, mock data, assert rendered data, trigger interaction, assert callback fired. **MSW handlers:** Mock each API endpoint used by the feature — return realistic data shapes. **Async state tests:** test loading (isLoading=true → spinner), error (isError=true → error message), success (data present → content). **Integration:** render page, mock API with MSW, simulate full user flow, assert final state | `task(subagent="TestEngineer")` | 🦸 |
| 👁️ Review | All three states tested per component. MSW handlers match real API shapes. No `test.todo` or skipped tests. Tests are deterministic (no flaky timing dependencies). Coverage ≥80% | `task(subagent="CodeReviewer")` | 🦸 |
| ✅ Verify | Tests pass locally. Coverage report shows uncovered lines — are they critical? (Getters, type definitions are fine uncovered. Business logic is not.) | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** Testing implementation details (state variables, internal function calls) makes tests brittle — every refactor breaks them. Test behavior: what does the user see? What happens when they click? Also: `vi.mock()` at the module level hoists above imports — if you need per-test mock behavior, use `vi.hoisted()` or MSW instead.

---

## Scenario F12: Performance & Bundle Size

**When:** Slow initial load, large JS bundle, laggy interactions, or Lighthouse score below target.
**Success:** Code split by route (lazy loading), TanStack Query caching tuned, images optimized, Lighthouse score 90+ (Performance), bundle chunks under 200KB each.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 🔍 Profile | Run Lighthouse audit (DevTools → Lighthouse → Performance). Check Network tab: total JS size, largest chunks, render-blocking resources. Run `npm run build && npx vite-bundle-visualizer` to see chunk sizes | Manual + Lighthouse + bundle analyzer | — |
| 🔍 Analyze | Identify: which chunks are too large (>200KB)? Which routes aren't lazy-loaded? Are there duplicate dependencies? Is Tailwind purging working (unused CSS in build)? Are images optimized? | Manual + build output analysis | — |
| 🔨 Fix | **Code splitting:** Convert direct imports to `React.lazy(() => import('./HeavyPage'))` + `<Suspense>`. **Chunk splitting:** Configure `vite.config.ts` `build.rollupOptions.output.manualChunks` to separate vendor chunks (React, TanStack, Tailwind are each ~40-50KB — keep them separate for caching). **Image optimization:** Use `<img srcset>` for responsive images, WebP format, lazy loading (`loading="lazy"`). **Cache tuning:** Set `staleTime` on queries that don't change often (admin stats: 5 min, triage result: 0 — always fresh). **Bundle analysis:** Verify chunks are under 200KB after splitting | `task(subagent="CoderAgent")` | 🦸 |
| ✅ Verify | Re-run Lighthouse — Performance >90. Build output — no chunk >200KB (node_modules excluded). Network tab — JS loads in parallel chunks. Repeat visits use cached chunks | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** Lazy loading everything makes the app feel slow (spinners everywhere between pages). Only lazy-load routes, not individual components. The initial route (homepage) should NOT be lazy-loaded — it's the first thing users see. Also: code splitting can break if you rename files — the dynamic import string (`import('./PageName')`) must match the actual filename at build time.

---

## Scenario F13: Accessibility (WCAG AA)

**When:** Auditing accessibility, fixing audit findings, or implementing accessible patterns from the start.
**Success:** Keyboard navigation works throughout, screen reader announces content correctly, color contrast meets WCAG AA (4.5:1 text, 3:1 large), focus management is logical.

| Gate | Action | Tool | Origin |
|------|--------|------|--------|
| 📚 Research | Fetch WCAG 2.1 AA checklist, ARIA authoring practices for React components (dialogs, tabs, menus, forms). Also: how to test accessibility with screen readers and automated tools | `task(subagent="ExternalScout")` | 🦸 |
| 🔍 Audit | Run axe DevTools on every page. Manually test: Tab through the page — can you reach and activate every interactive element? Is the focus order logical? Are there focus traps in modals? Is there a "skip to content" link? Turn on VoiceOver/NVDA — are images described? Are form labels announced? Are dynamic updates (polling results) announced? | Manual audit + axe DevTools | — |
| 🔨 Fix | **Focus management:** `tabIndex={-1}` on non-interactive containers that should receive focus (modal title, new page heading). **Keyboard handlers:** `onKeyDown` for Enter/Space on custom buttons, Escape on modals. **ARIA labels:** `aria-label` on icon-only buttons, `aria-labelledby` for sections, `aria-live="polite"` for polling status updates. **Color contrast:** Check urgency colors against text — EMERGENCY red may not have enough contrast with white text. Adjust colors if needed. **Form labels:** Every input has a visible `<label>` with `htmlFor`. **Skip link:** `<a href="#main-content" className="sr-only focus:not-sr-only">` as first focusable element | `task(subagent="CoderAgent")` | 🦸 |
| 🧪 Test | Automated: axe DevTools zero violations. Manual: Tab through full triage flow, submit form with keyboard only, navigate admin with screen reader. Assert focus lands on result card after polling completes (use `aria-live` region) | `task(subagent="TestEngineer")` | 🦸 |
| ✅ Verify | axe audit clean. Keyboard navigation complete (no mouse needed). Screen reader announces: form steps, loading state ("Analyzing your symptoms"), result ("Your triage result: High urgency, cardiologist recommended"). Focus visible at all times (no `outline: none` without replacement) | `skill("verification-before-completion")` | 🦸 |

**⚠️ Watch out:** `aria-live` regions are powerful but easy to misuse. `aria-live="assertive"` interrupts the screen reader immediately — use only for critical alerts (errors). `aria-live="polite"` waits for the current announcement to finish — use for status updates (polling results). Also: don't add ARIA attributes that duplicate native semantics — `<button>` already announces as a button, don't add `role="button"` to it.

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
Auth flow?            → external-scout → context-scout → grill-with-docs → coder → test-engineer → review → verify
Error handling?       → context-scout → grill-with-docs → coder → test-engineer → review → verify
Testing strategy?     → context-scout → grill-with-docs → test-engineer → review → verify
Performance?          → profile (Lighthouse + bundle analyzer) → coder → verify (re-profile)
Accessibility?        → external-scout → audit (axe + manual) → coder → test-engineer → verify
```

**Cross-reference:** Backend scenarios → [`tools-scenarios-backend.md`](tools-scenarios-backend.md) | Master reference → [`tools-scenarios-matrix.md`](tools-scenarios-matrix.md)
