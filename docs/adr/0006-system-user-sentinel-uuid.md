# System user with fixed UUID for synthetic submissions

Synthetic triage submissions need a User owner (the `TriageSubmission` entity requires a `User` reference), but no real person created them. Rather than making `user_id` nullable (which would require nullable FK + conditional ownership checks everywhere) or picking a real user at runtime (which would mix synthetic data onto a real user's submission history), a dedicated system user is seeded via migration with a fixed, recognizable UUID `00000000-0000-0000-0000-000000000001`, the role `ROLE_SYSTEM`, and an empty password.

The empty password is intentional — the system user's authentication path is never exercised. It's referenced only by UUID in scheduler and admin handler code, never loaded into a security context. `ROLE_USER` is intentionally omitted because the user is never in a login flow that would check it.

The alternative — a `findOrCreate` call on every scheduler tick — would add a DB query per tick and a race window where concurrent scheduler workers could create duplicate system users. The migration-based seed is deterministic, zero-cost at runtime, and guarantees exactly one system user with a predictable UUID that any handler can reference without a DB lookup. The `down()` migration cleanly removes it if needed, keeping reversibility.
