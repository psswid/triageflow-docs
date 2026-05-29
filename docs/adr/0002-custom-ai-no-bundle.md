# Custom AI integration — no symfony/ai-bundle

The plan assumed `symfony/ai-bundle` would provide an `ai:` YAML config key with platform/agent autowiring. As of 2026-05, no such package exists on Packagist.

AI calls are implemented via `symfony/http-client` directly, using a custom `config/packages/ai.yaml` for OpenRouter parameters (base URL, API key, default/fallback model, timeout, max_tokens, temperature). The config lives in `parameters.ai.openrouter.*` — not a bundle-owned config tree.

If a stable `symfony/ai-bundle` ships later, the migration path is:

1. Replace `parameters:` block with `ai:` config tree
2. Swap manual HTTP Client calls for bundle-injected AI service
3. Remove custom service wiring

Until then, the `ai.yaml` comment block documents this as a deliberate architectural deviation.
