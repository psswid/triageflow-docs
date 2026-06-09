# Single aggregate: TriageSubmission with embedded TriageOutcome

TriageSubmissions own their triage outcomes — the outcome is a Doctrine Embeddable value object, not a separate entity, because it's never accessed or queried independently of its submission. An outcome exists only as the terminal state of an interview; there's no domain operation that needs "all outcomes by specialist X" without also loading the full submission context.

The alternative — a separate `triage_outcomes` table with a FK back to `triage_submissions` — would require a join on every result-page load and permit orphaned outcomes or multiple outcomes per submission, invariants the domain doesn't allow. Embedding the three fields (`specialist`, `urgency`, `justification`) directly into the submission row makes persistence atomic, eliminates joins, and enforces the one-per-submission invariant at the schema level.

The cost: you can't query outcomes without loading submissions. This is acceptable because the app never does that.
