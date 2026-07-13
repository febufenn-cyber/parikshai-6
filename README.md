# Parikshai

> A trusted Tamil-first learning engine for government-exam practice: focused daily questions, clear mistake explanations, and practice that adapts to weak topics.

**Status:** Phase 1 engineering foundation is implemented. The canonical truth layer now has versioning, provenance, review states, controlled publication, suppression, correction lineage, RLS boundaries, fixture validation, and database contract tests. Public scored launch remains blocked on the Phase 0 learner, language, content-sample, pilot, and economics gates.

## Opening position

- **Provisional public wedge:** TNPSC Group IV, Tamil-first with bilingual technical terminology.
- **Internal proving ground:** the founder's existing UGC-NET corpus and question-quality learnings.
- **First loop:** diagnostic → 10-question daily practice → mistake explanation → weakness update → next-practice recommendation.
- **Truth rule:** verified content is scored; generated content is quarantined until validated.
- **AI role:** tutor and content assistant, never silent authority over official answers.
- **Permanent identity:** Supabase authenticated user ID, not name, device, or onboarding data.

## Implemented foundation

- Phase 0 product constitution and evidence gates
- Supabase/Postgres canonical truth-layer migrations
- Stable questions plus immutable learner-visible versions
- Provenance, syllabus mapping, options, assets, passages, and explanations
- Editorial reviews, validator results, reports, and correction-impact records
- Database-enforced publication, suppression, and archive functions
- Answer-free learner views and backend-only canonical answer records
- RLS learner/editor boundaries with constrained question-report writes
- Dependency-free fixture validation and GitHub Actions CI
- pgTAP database contract tests

## Phase map

- **Phase 0 — Choose the board:** product constitution, wedge, trust rules, evidence plan, economics, risks.
- **Phase 1 — Truth layer:** canonical content model, provenance, versioning, review workflow, safe publication. **Engineering foundation implemented.**
- **Phase 2 — Learning loop:** onboarding, diagnostic, daily practice, mistake review, offline/idempotent attempts, progress restoration.
- **Phase 3 — Learner model:** deterministic mastery and next-best-practice selection.
- **Phase 4 — Grounded tutor:** source-backed Tamil explanations and misconception checks.
- **Phase 5 — Controlled generation:** offline candidate generation, critics, validators, review, rollback.

Start with:

- [`docs/phase-0/PHASE_0.md`](docs/phase-0/PHASE_0.md)
- [`docs/phase-1/PHASE_1.md`](docs/phase-1/PHASE_1.md)
- [`supabase/README.md`](supabase/README.md)

## Validation

```bash
npm test
```

With Supabase CLI installed and the project initialized:

```bash
supabase start
supabase db reset
supabase test db
```

## Architecture boundary

`Clients → Cloudflare Worker/Hono API → Supabase Postgres/Auth/Storage`

AI generation, translation, and evaluation run behind queues where possible. Core practice must continue when model services are unavailable. Application routes must call the database publication contract rather than reproducing trust rules in client or API code.

## Non-goals for the opening

No multi-exam launch, eight-language launch, live unreviewed question generation, coaching marketplace, social feed, elaborate gamification, rank guarantees, or TTS dependency.

---

Initial blueprint created with Fable 5. Phase 0 made the position falsifiable; Phase 1 makes content truth enforceable.
