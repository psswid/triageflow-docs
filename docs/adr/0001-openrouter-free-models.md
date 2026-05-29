# OpenRouter free models for demo app

The TriageFlow demo app uses OpenRouter free models (e.g. `google/gemma-4-31b-it:free`) for all AI calls — triage interviews and synthetic case generation. Development sessions use DeepSeek V4 Pro/Flash, which was the default assumption when writing the agent configuration.

The trade-off: OpenRouter free tier costs nothing but has rate limits and variable quality. For a portfolio demo running synthetic traffic, zero cost is the right priority. The `symfony/ai` integration layer abstracts the provider, so switching to a paid model later is a configuration change, not a rewrite.
