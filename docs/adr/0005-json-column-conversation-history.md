# JSON column for conversation history

The triage interview conversation (initial description + follow-up Q&A turns) is stored as a JSON column in the `triage_submissions` row rather than as rows in a normalized `conversation_turns` or `messages` table. The conversation is an append-only transcript — the app always reads the full history, never individual messages, and never queries across conversations (e.g. "all messages containing the word 'headache'").

A separate turns table would add schema migrations for each message type, require ordering by a `created_at` or sequence column, and introduce a one-to-many relationship that joins on every interview render. The JSON approach keeps the schema minimal, avoids joins, and allows the `{type, content, timestamp}` entry schema to evolve without migrations (new entry types are backward-compatible).

The downside: you can't run SQL analytics across messages. This is acceptable because the system generates synthetic data — any analytics would be done against the source generator, not the stored transcripts.
