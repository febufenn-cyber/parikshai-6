# Phase 1 implementation summary

Phase 1 converts the product constitution into an enforceable canonical-content system.

The main result is a versioned Postgres model where publication is a controlled workflow rather than a mutable boolean. The database requires evidence for answer, explanation, language, rendering, provenance, and syllabus mapping before a non-experimental version can become learner-visible. Published payloads are immutable; corrections create successors and preserve impact records.

The learner boundary is intentionally narrower than the editorial boundary. Clients receive answer-free security-barrier views, while canonical answers and explanation bodies remain backend-only until Phase 2 records a submission. Reports are allowed, but learner inserts cannot set staff-owned status, severity, or resolution fields.

Repository CI validates fixtures and static SQL contracts. A 34-assertion pgTAP suite is included for execution in a local/staging Supabase environment. The absence of PostgreSQL/Supabase CLI in the current execution environment is recorded explicitly; database execution remains a Phase 2 entry gate.
