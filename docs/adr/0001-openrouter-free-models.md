# OpenRouter free models for demo app

The TriageFlow demo app uses OpenRouter free models for all AI calls — triage interviews and synthetic case generation. The model is configured as `openrouter/free` (OpenRouter's meta-router that selects the best available free model), with `openai/gpt-oss-120b:free` as a fallback if rate-limited. Development sessions use DeepSeek V4 Pro/Flash, which was the default assumption when writing the agent configuration.

The trade-off: OpenRouter free tier costs nothing but has rate limits and variable quality. For a portfolio demo running synthetic traffic, zero cost is the right priority. The AI integration layer (custom HTTP Client wrapper — see ADR-0002) abstracts the provider, so switching to a paid model later is a configuration change, not a rewrite.
