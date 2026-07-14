# Parikshai Phase 2 — Smallest Complete Learning Loop

**Engineering status:** implemented foundation.  
**Staging status:** blocked until Phase 1 and Phase 2 migrations and pgTAP suites execute in a target Supabase/Postgres environment.

## Mission

Create a complete, reliable learner loop over verified Phase 1 content:

`anonymous onboarding → optional account attachment → session creation → answer-free question delivery → idempotent submission → verified reveal → review/bookmark/report → restoration`

Phase 2 proves continuity and trust. It deliberately does not implement adaptive mastery, AI tutoring, generation, billing, or a polished client application.

## Position evaluation

The obvious implementation would let a client query questions and answers directly, store attempts locally, and sync later. That loses the game tactically: answer endpoints become oracles, duplicate retries create multiple attempts, anonymous UUIDs can be hijacked, and edits can detach an attempt from the exact question shown.

The prophylactic implementation is:

- backend-only access to the `learning` schema;
- server-issued anonymous ID plus high-entropy secret;
- exact `question_version_id` snapshots in every session;
- atomic scoring and reveal in one database transaction;
- append-only submission/result/evidence payloads, with a guarded owner-field-only reassignment during account attachment;
- globally unique idempotency keys with request-hash conflict detection;
- non-destructive anonymous-to-auth attachment;
- restoration from server state rather than names or device IDs.

## Architecture

`Client → Cloudflare Worker/Hono → Supabase Auth verification → service-role PostgREST RPC → learning/content schemas`

The service-role key exists only in Worker secrets. Browser/mobile clients never query canonical answers or learning history tables directly.

### Worker boundaries

- `src/env.ts`: startup/readiness environment validation.
- `src/auth.ts`: bearer-token or anonymous-secret identity resolution.
- `src/db/supabase-rest.ts`: service-role RPC and Supabase Auth user verification.
- `src/services.ts`: domain operations independent of HTTP routing.
- `src/app.ts`: versioned Hono routes, request IDs, structured errors.
- `src/domain/validation.ts`: request and answer-boundary validation.

## Data model

### Identity

- `learning.learner_profiles`: permanent profile keyed only by `auth.users.id`.
- `learning.anonymous_identities`: server-issued anonymous identity with hashed secret.
- `learning.identity_migrations`: append-only, idempotent attachment audit.

### Sessions

- `learning.practice_sessions`: diagnostic, daily, or topic session.
- `learning.session_questions`: immutable ordinal and exact question-version snapshot.
- `learning.session_recovery`: monotonic resume cursor and client state version.

### Attempts and evidence

- `learning.answer_submissions`: append-only learner response and idempotency key.
- `learning.answer_results`: one canonical result per submission.
- `learning.idempotency_receipts`: cached successful response plus request hash.
- `learning.evidence_events`: append-only raw evidence for Phase 3 derivation.
- `learning.bookmarks`: version-specific saved questions.

## API contract

### Health

- `GET /healthz`
- `GET /readyz`

### Identity/profile

- `POST /v1/identities/anonymous`
- `POST /v1/identities/attach`
- `PUT /v1/me/profile`
- `GET /v1/me/restore`

### Sessions

- `POST /v1/sessions`
- `GET /v1/sessions/:sessionId`
- `GET /v1/sessions/:sessionId/questions/:ordinal`
- `POST /v1/sessions/:sessionId/submissions`
- `POST /v1/sessions/:sessionId/complete`
- `GET /v1/sessions/:sessionId/review/:ordinal`

### Utilities

- `PUT|DELETE /v1/bookmarks/:questionVersionId`
- `POST /v1/reports`

## Core invariants

1. Exactly one owner exists for every session, submission, bookmark, receipt, and evidence event.
2. Authenticated identity is always the verified Supabase user ID.
3. Anonymous identity requires both ID and secret; the database stores only a hash.
4. Account attachment is non-destructive and idempotent.
5. Session questions reference the exact immutable question version shown.
6. Pre-submission payloads reject answer-bearing keys recursively.
7. New sessions contain only eligible, currently published questions.
8. A final submission is immutable and unique per session question.
9. Retrying the same idempotency key and request returns the stored response.
10. Reusing an idempotency key with different data is rejected.
11. Answer material is returned only by the atomic submission/review workflow.
12. Scoring requires a verified canonical answer.
13. Raw evidence is append-only and does not pretend to be mastery.
14. Display-name changes cannot alter ownership.
15. Direct `anon` and `authenticated` table access is revoked.

## Anonymous-to-auth merge

Attachment locks the anonymous identity, verifies the secret, and migrates sessions, submissions, evidence, receipts, and bookmarks to the authenticated user. Existing authenticated profile data is preserved. Bookmark conflicts collapse safely. A second attachment to a different account is rejected.

## Offline/retry model

Clients create UUID idempotency keys before network submission. The database hashes the semantic request and stores the successful response. Network retries therefore cannot create duplicate attempts. Conflicting reuse is a hard error rather than silent overwrite.

The session recovery cursor advances monotonically after accepted submissions. Reinstall restoration comes from authenticated server state; anonymous state requires retained anonymous credentials until account attachment.

## Correction compatibility

Attempts retain exact `question_version_id` references and immutable answer/result snapshots. Phase 1 corrections can later identify impacted results without rewriting what the learner originally saw. Phase 3 may derive recalculated evidence through new events rather than mutating original evidence.

## Failure behaviour

- Invalid/expired auth: `401 invalid_token`.
- Missing identity: `401 authentication_required`.
- Foreign session/question: rejected by ownership and membership checks.
- Duplicate same request: previous response with `replayed: true`.
- Duplicate different request: idempotency conflict.
- Suppressed question after session creation: original snapshot remains reconstructable; scoring eligibility is checked at submission and operational policy decides invalidation.
- Model outage: irrelevant to the core Phase 2 loop.
- Database unavailable: structured `503 database_error`.

## Acceptance criteria

- Anonymous identities cannot be claimed using ID alone.
- Account attachment preserves anonymous work and cannot attach to two users.
- Session order and versions remain stable across resume.
- Pre-submission API responses contain no answer/explanation material.
- Final submission is atomic, immutable, and idempotent.
- Reveal contains canonical result only after accepted submission.
- Cross-user access is rejected.
- Reinstall restore is keyed by authenticated ID.
- Database and application answer-boundary checks both exist.
- Unit tests, static contracts, TypeScript checking, CI, and pgTAP tests are present.

## Operational commands

```bash
npm install
npm test
npm run typecheck
supabase db reset
supabase test db
wrangler dev
```

Before deployment, expose the `learning` schema to PostgREST only for the backend project configuration, keep all functions service-role-only, and store Supabase keys through `wrangler secret put`.
