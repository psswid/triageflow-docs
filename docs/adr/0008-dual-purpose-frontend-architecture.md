# Dual-purpose frontend: authenticated SPA + public business website

The frontend serves dual duty: an authenticated single-page application (the triage tool itself) and a public-facing business website with marketing pages. The original scaffold had only an authenticated app — login redirected straight to `/triage` with no public surface.

The alternative — splitting into two separate apps (one marketing site, one SPA) — would require separate Vite builds, duplicated design tokens, cross-origin auth issues, and a reverse-proxy routing layer. Keeping everything in one React app with two layout wrappers (`MarketingLayout` for public pages, `AppLayout` for authenticated pages) means a single build pipeline, shared design tokens, unified i18n, and consistent dark mode across both surfaces. The route tree splits at the top level: public routes under `MarketingLayout`, auth pages standalone (no layout), protected routes under `AppLayout`.

The cost: the marketing bundle includes the full React/Query/Router stack even though the landing page uses none of it. For a portfolio demo this is negligible. For production you'd split into separate entry points or a multi-page setup.
