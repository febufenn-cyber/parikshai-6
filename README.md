# Parikshai

> A trusted Tamil-first learning engine for government-exam practice: focused daily questions, clear mistake explanations, and practice that adapts to weak topics.

**Status:** Phase 0 strategic foundation is implemented as a reviewable product constitution. The public launch wedge is provisional until learner interviews and prototype evidence satisfy the Phase 1 entry gate.

## Opening position

- **Provisional public wedge:** TNPSC Group IV, Tamil-first with bilingual technical terminology.
- **Internal proving ground:** the founder's existing UGC-NET corpus and question-quality learnings.
- **First loop:** diagnostic → 10-question daily practice → mistake explanation → weakness update → next-practice recommendation.
- **Truth rule:** verified content is scored; generated content is quarantined until validated.
- **AI role:** tutor and content assistant, never silent authority over official answers.
- **Permanent identity:** Supabase authenticated user ID, not name, device, or onboarding data.

## Phase map

- **Phase 0 — Choose the board:** product constitution, wedge, trust rules, evidence plan, economics, risks.
- **Phase 1 — Truth layer:** canonical content model, provenance, versioning, review workflow, reliable renderer.
- **Phase 2 — Learning loop:** onboarding, diagnostic, daily practice, mistake review, progress restoration.
- **Phase 3 — Learner model:** deterministic mastery and next-best-practice selection.
- **Phase 4 — Grounded tutor:** source-backed Tamil explanations and misconception checks.
- **Phase 5 — Controlled generation:** offline candidate generation, critics, validators, review, rollback.

Start with [`docs/phase-0/PHASE_0.md`](docs/phase-0/PHASE_0.md).

## Proposed architecture boundary

`Clients → Cloudflare Worker/Hono API → Supabase Postgres/Auth/Storage`

AI generation, translation, and evaluation run behind queues where possible. Core practice must continue when model services are unavailable.

## Non-goals for the opening

No multi-exam launch, eight-language launch, live unreviewed question generation, coaching marketplace, social feed, elaborate gamification, rank guarantees, or TTS dependency.

---

Initial blueprint created with Fable 5. Phase 0 turns that seed into an explicit, falsifiable product position.
