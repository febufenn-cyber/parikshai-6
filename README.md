# Parikshai

> A trusted Tamil-first learning engine for government-exam practice: focused daily questions, clear mistake explanations, and practice that adapts to weak topics.

**Status:** Phase 2 engineering foundation is implemented. The repository now contains the canonical content truth layer plus an authenticated/anonymous learning-loop API with immutable sessions, idempotent submissions, post-submission reveal, bookmarks, reports, raw evidence, and restoration. Scored staging remains blocked until the Supabase migrations and pgTAP suites execute against the target project.

## Opening position

- **Provisional public wedge:** TNPSC Group IV, Tamil-first with bilingual technical terminology.
- **Internal proving ground:** the founder's existing UGC-NET corpus and question-quality learnings.
- **First loop:** diagnostic → 10-question daily practice → mistake explanation → weakness update → next-practice recommendation.
- **Truth rule:** verified content is scored; generated content is quarantined until validated.
- **AI role:** tutor and content assistant, never silent authority over official answers.
- **Permanent identity:** Supabase authenticated user ID, not name, device, or onboarding data.

## Implemented foundation

- Phase 0 product constitution and evidence gates
- Phase 1 canonical truth layer, controlled publishing, correction lineage, and answer-free learner views
- Cloudflare Worker + Hono TypeScript API
- Server-issued anonymous identities with hashed secrets
- Non-destructive anonymous-to-auth progress attachment
- Diagnostic, daily, and topic practice sessions
- Immutable session-question snapshots tied to exact question versions
- Atomic, idempotent answer submission and verified result reveal
- Append-only results and raw learning evidence
- Bookmarks, question reports, and reinstall/multi-device restoration contracts
- Backend-only service-role RPC boundary
- TypeScript, unit, static-contract, roadmap, and pgTAP test suites

## Remaining implementation phases

1. **Phase 3 — Learner model:** deterministic mastery evidence and next-best-practice selection.
2. **Phase 4 — Grounded tutor:** source-backed Tamil/bilingual explanations, evaluation, caching, and cost controls.
3. **Phase 5 — Controlled generation:** quarantined candidate generation, critics, validators, review, duplicate control, and rollback.

The controlling autonomous plan is [`docs/roadmap/REMAINING_PHASES.md`](docs/roadmap/REMAINING_PHASES.md). Machine-readable progress is stored in [`docs/roadmap/phase-status.json`](docs/roadmap/phase-status.json).

## Phase map

- **Phase 0 — Choose the board:** complete.
- **Phase 1 — Truth layer:** engineering foundation complete.
- **Phase 2 — Learning loop:** engineering foundation complete; target database/staging validation still required.
- **Phase 3 — Learner model:** next eligible phase after Phase 2 completion metadata is recorded.
- **Phase 4 — Grounded tutor:** planned after Phase 3.
- **Phase 5 — Controlled generation:** planned after Phase 4.

Start with:

- [`docs/phase-0/PHASE_0.md`](docs/phase-0/PHASE_0.md)
- [`docs/phase-1/PHASE_1.md`](docs/phase-1/PHASE_1.md)
- [`docs/phase-2/PHASE_2.md`](docs/phase-2/PHASE_2.md)
- [`docs/roadmap/REMAINING_PHASES.md`](docs/roadmap/REMAINING_PHASES.md)
- [`supabase/README.md`](supabase/README.md)

## Install and validate

```bash
npm install
npm test
npm run typecheck
```

With Supabase CLI installed and the project initialized:

```bash
supabase start
supabase db reset
supabase test db
```

Run the Worker locally:

```bash
cp .dev.vars.example .dev.vars
npx wrangler dev
```

## Architecture boundary

`Clients → Cloudflare Worker/Hono API → Supabase Auth/PostgREST → learning/content schemas`

The service-role key remains Worker-only. Learner clients never receive direct access to canonical answers, attempt tables, or evidence tables. AI generation, translation, and evaluation remain later-phase asynchronous capabilities; the core practice loop does not depend on model availability.

## Non-goals for the opening

No multi-exam launch, eight-language launch, live unreviewed question generation, coaching marketplace, social feed, elaborate gamification, rank guarantees, or TTS dependency.
