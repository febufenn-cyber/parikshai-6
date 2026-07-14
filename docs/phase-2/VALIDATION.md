# Phase 2 validation record

Date: 2026-07-14

## Designed checks

- `npm test`
  - Phase 1 fixture and SQL contracts;
  - roadmap/status validation;
  - Phase 2 migration, API-route, answer-boundary, idempotency, documentation, and pgTAP-plan contracts;
  - Hono/domain unit tests.
- `npm run typecheck`
  - strict TypeScript validation for Worker, service, RPC, auth, validation, and tests.
- GitHub Actions installs pinned dependencies and runs both commands.

## Unit/negative coverage

- server-generated anonymous secret;
- recursive pre-submission answer-material rejection;
- anonymous identity passed only through backend RPC fields;
- identity required for question delivery;
- answer absent before submission;
- answer present only after submission route;
- authenticated restoration unaffected by display name.

## Database suite

`supabase/tests/phase_2_learning_loop.sql` contains structural pgTAP assertions for:

- identity/session/submission/result/recovery/evidence tables;
- backend workflow functions;
- exact-version and idempotency columns;
- answer-boundary and append-only triggers;
- absence of direct learner privileges.

## Not yet executable in this environment

No target Supabase/Postgres project is connected. Therefore this document does not claim that migrations execute or database workflows pass dynamically.

Required before scored staging use:

```bash
supabase start
supabase db reset
supabase test db
```

Then exercise once in staging:

1. create anonymous identity;
2. create verified published content fixtures;
3. create/resume a session;
4. submit the same request twice and verify one attempt;
5. reuse the key with a different answer and verify conflict;
6. attach anonymous work to an auth user;
7. reinstall/sign in and verify restoration;
8. suppress/correct one attempted question and verify impact traceability.

CI result and final diff inspection are appended in the PR record before merge.
