# Phase 2 handoff to Phase 3

## Phase 3 may rely on

- permanent identity keyed by `auth.users.id`;
- anonymous-to-auth attachment audit;
- immutable session-question snapshots;
- append-only submissions and canonical results;
- exact question-version references;
- primary syllabus node captured in raw evidence when available;
- elapsed time and correctness evidence;
- idempotent retries and restoration state;
- backend-only answers and explanations.

## Intentionally absent

- mastery scores;
- confidence bands;
- spaced-repetition scheduling;
- next-best-question ranking;
- misconception taxonomy;
- AI-generated explanations;
- live question generation;
- public client UI;
- production abuse/rate-limit configuration.

## Phase 3 entry gate

1. Phase 2 PR is merged and status manifest records its merge SHA.
2. GitHub Actions passes `npm test` and `npm run typecheck`.
3. Phase 1 and Phase 2 database migrations and pgTAP suites pass in Supabase/Postgres.
4. At least one end-to-end staging flow proves anonymous → session → submission → attach → restore.
5. Evidence replay produces deterministic raw inputs without duplicates.
6. Any schema corrections are added as successor migrations, never by editing applied migrations.

## Unresolved external gates

Market wedge, Tamil/bilingual preference, real truth sample, pilot retention, and unit economics remain outside engineering completion and must not be inferred from code.
