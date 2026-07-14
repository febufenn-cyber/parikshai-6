# Phase 2 threat model

## Protected assets

- learner identity and progress;
- anonymous credentials;
- canonical answers and explanations;
- exact session/question history;
- idempotency integrity;
- service-role key;
- raw learning evidence;
- other learners' sessions and submissions.

## Trust boundaries

1. Untrusted mobile/browser client → Worker API.
2. Worker bearer token → Supabase Auth.
3. Worker service-role secret → PostgREST RPC.
4. Learning workflows → canonical content tables.
5. Offline client retry queue → idempotency receipt store.

## Threats and mitigations

| Threat | Severity | Mitigation / test |
|---|---:|---|
| Guess or steal anonymous UUID | Critical | Require 256-bit server-generated secret; hash at rest |
| Attach anonymous work to wrong account | Critical | Lock identity, verify secret, reject already-attached different user, audit migration |
| Service-role key leaks to client | Critical | Worker-only binding; no client SDK using service role; repository secret scan/contract checks |
| Query answer before submission | Critical | Answer-free snapshots, recursive forbidden-key checks, backend-only tables |
| Generic reveal endpoint becomes answer oracle | Critical | Review requires owned session question with stored final result |
| Duplicate offline retries create attempts | High | Idempotency receipt and request hash; one final submission per session question |
| Same idempotency key used for different request | High | Hard conflict, never return unrelated response |
| Submit into another user's session | Critical | Database owner match and session-question membership checks |
| Change question after learner saw it | High | Exact immutable version and public snapshot |
| Display-name mismatch creates/steals account | Critical | Ownership only by verified `auth.users.id` |
| Migration overwrites newer server data | High | Preserve authenticated profile, merge only non-destructive entities |
| Forge correctness/result from client | Critical | Canonical answer read and scoring inside security-definer function |
| Tamper with raw evidence | High | Append-only triggers and no learner table grants |
| Suppressed question still scores silently | High | Scoring eligibility check and later correction impact workflow |
| Report spam | Medium | Auth/anonymous credential requirement, bounded fields; rate limiting before public release |
| Cost amplification via session creation | Medium | Question-count cap 50; deployment rate limits still required |
| RPC error leaks secrets | High | Structured errors; never include environment or anonymous secret in response/logging |

## Negative tests required

- no identity receives 401;
- nested answer key in pre-submission payload is rejected;
- foreign session access fails;
- second final submission fails;
- duplicate identical request replays;
- duplicate conflicting request fails;
- anonymous ID without secret fails;
- attachment to second user fails;
- direct authenticated table access is absent;
- append-only rows reject mutation.

## Residual risks

- Target Supabase execution is not yet proven.
- API-level rate limiting and abuse quotas are not implemented in this phase.
- Anonymous progress is unrecoverable if the user loses both local credentials before attaching an account.
- Full client-side encrypted offline queue remains a client responsibility.
