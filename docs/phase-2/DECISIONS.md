# Phase 2 decision log

Append decisions; do not rewrite history.

| Date | Decision | Status | Rationale / revisit trigger |
|---|---|---|---|
| 2026-07-14 | Use Cloudflare Workers + Hono with service-role PostgREST RPCs | Locked for Phase 2 | Keeps secrets server-side and domain services testable; revisit during platform migration |
| 2026-07-14 | Anonymous identity requires an ID plus server-generated secret | Locked | UUID-only ownership is hijackable |
| 2026-07-14 | Hash anonymous secrets in Postgres | Locked | Plaintext credentials must not persist |
| 2026-07-14 | Session questions store immutable answer-free snapshots | Locked | Required for resume, replay, and correction audit |
| 2026-07-14 | Scoring and reveal occur in one atomic database function | Locked | Prevents answer-oracle and partial-write states |
| 2026-07-14 | Idempotency keys are globally unique and request-hash bound | Locked | Duplicate offline retries must be safe; conflicting reuse must fail |
| 2026-07-14 | Raw evidence is append-only; mastery remains Phase 3 | Locked until Phase 3 | Avoids false intelligence in the learning-loop phase |
| 2026-07-14 | Direct learner access to `learning` tables/functions is revoked | Locked | API mediates identity, answer timing, and ownership |
| 2026-07-14 | Phase 2 can merge with database execution explicitly blocked | Conditional | Engineering is useful now, but scored staging cannot proceed until Supabase tests pass |
