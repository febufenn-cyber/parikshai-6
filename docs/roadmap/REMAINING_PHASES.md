# Parikshai Remaining Phases — Autonomous Implementation Plan

**Roadmap version:** 1.0  
**Date established:** 2026-07-14  
**Controlling status file:** [`phase-status.json`](./phase-status.json)  
**Current position:** Phase 0 and Phase 1 are complete; four implementation phases remain.

This document is the controlling plan for implementing the remaining Parikshai roadmap. It exists so that a future implementation does not depend on conversational memory, hidden assumptions, or an improvised feature list.

The command **`build`** means: implement the next incomplete phase described here, verify it, commit it, push its branch, open a pull request, merge it into `main`, and confirm the resulting `main` commit. The build must finish in one execution unless a genuinely external prerequisite makes completion impossible. Missing product evidence must be recorded honestly; it must never be fabricated.

---

## 1. How many phases remain?

Four implementation phases remain:

| Phase | Name | Primary result |
|---|---|---|
| 2 | Learning loop | A learner can onboard, practise verified questions, submit safely, review mistakes, and restore progress |
| 3 | Learner model | Deterministic mastery evidence and next-best-practice recommendations |
| 4 | Grounded tutor | Source-backed Tamil/bilingual mistake explanations with caching, evaluation, and cost controls |
| 5 | Controlled generation | Quarantined question generation with critics, validators, review, duplicate control, and rollback |

Phase 0 chose the board and established evidence gates. Phase 1 created the canonical truth layer. They are not reopened casually.

A **production release gate** follows Phase 5, but it is not counted as a separate implementation phase. It verifies the whole system against real content, real learners, security, cost, and operational requirements before public scored launch.

---

## 2. Governing principles

Every remaining phase must preserve these locked decisions:

1. Verified content is the only content allowed to affect scoring until equivalent review evidence exists.
2. Experimental or generated content remains quarantined.
3. Learner attempts reference the exact immutable question version shown.
4. The authenticated Supabase user ID is the permanent learner identity.
5. Names, device IDs, language choices, and onboarding responses never define account ownership.
6. Core practice remains usable when model providers are unavailable.
7. AI cannot silently override official truth.
8. Corrections preserve history and trigger deterministic impact handling.
9. RLS is not treated as column-level secrecy; answers remain behind backend-controlled submission flows.
10. A phase is not complete merely because files exist. Its acceptance tests and exit gate must pass or the limitation must be recorded explicitly.

---

## 3. Autonomous `build` command contract

### 3.1 Default interpretation

When the user says exactly **`build`**, implement the next phase whose status is `ready` or `planned`, choosing the lowest phase number.

- One `build` command implements one phase.
- `build phase 4` implements the named phase only if all earlier required dependencies are complete.
- `build all` may implement all remaining phases sequentially, but each phase still receives its own branch, PR, merge commit, validation record, and status update.

### 3.2 Mandatory preflight

Before writing implementation code, the agent must:

1. Read this document and `phase-status.json` from `main`.
2. Run `npm test`, including the roadmap validator.
3. Verify that the previous phase is marked complete.
4. Verify the previous phase merge commit exists on `main`.
5. Read the previous phase handoff and unresolved limitations.
6. Check for open PRs or branches that overlap the target phase.
7. Inspect current repository structure instead of assuming it is unchanged.
8. Evaluate entry gates and classify each as:
   - `pass`;
   - `implementable_now`;
   - `externally_blocked`;
   - `not_applicable`.
9. Record any assumptions in the target phase decision log before relying on them.

### 3.3 No fabricated validation

The implementation may proceed when useful engineering work is possible, but it must not claim:

- database tests passed when no database was executed;
- learner demand was validated without real learner evidence;
- Tamil quality was reviewed without qualified review;
- a model integration worked without an actual provider call;
- deployment succeeded when no deployment target was used;
- CI passed before GitHub reports it.

Every unavailable verification must be listed in `docs/phase-X/VALIDATION.md` with the exact command or evidence still required.

### 3.4 Branch and merge protocol

For each phase:

1. Begin from the latest remote `main`.
2. Create `agent/phase-X-<slug>`.
3. Implement only the target phase plus required compatibility fixes.
4. Add or update:
   - `docs/phase-X/PHASE_X.md`;
   - `docs/phase-X/DECISIONS.md`;
   - `docs/phase-X/THREAT_MODEL.md`;
   - `docs/phase-X/VALIDATION.md`;
   - `docs/phase-X/HANDOFF.md`;
   - `docs/roadmap/phase-status.json`.
5. Add tests before declaring the phase complete.
6. Run all available repository checks.
7. Perform a red-team pass against the phase-specific blind spots.
8. Inspect `main...branch` for unrelated files and secret material.
9. Open a non-draft PR unless required checks are still pending.
10. Prefer squash merge so each phase lands as one clean commit.
11. Merge only when GitHub reports the PR mergeable and required checks are not failing.
12. Confirm:
    - PR state is merged;
    - merge commit SHA;
    - `main` contains the commit;
    - CI status or the explicit absence of CI status;
    - phase status manifest points to the merge commit.

### 3.5 Completion report

After each build, report:

- phase implemented;
- branch;
- PR number;
- merge commit SHA;
- validation performed;
- validation not performed and why;
- important blind spots closed;
- remaining external gates;
- the next phase now eligible for `build`.

---

## 4. Standard phase verification packet

Each phase must produce a packet that can be reviewed before merge.

### `PHASE_X.md`

- mission;
- position evaluation;
- scope and anti-goals;
- architecture;
- data model;
- API or workflow contract;
- invariants;
- failure handling;
- acceptance criteria;
- operational procedures.

### `DECISIONS.md`

An append-only table containing date, decision, status, rationale, and revisit trigger.

### `THREAT_MODEL.md`

- protected assets;
- trust boundaries;
- likely abuse cases;
- privacy risks;
- cheating risks;
- data-loss risks;
- cost-amplification risks;
- mitigations and tests.

### `VALIDATION.md`

- exact commands executed;
- observed results;
- CI results;
- negative tests;
- known environment limitations;
- remaining staging or human validation.

### `HANDOFF.md`

- what the next phase can rely on;
- what remains intentionally absent;
- migration or deployment notes;
- unresolved issues;
- entry gate for the next phase.

---

# Phase 2 — Smallest Complete Learning Loop

## 5. Mission

Create the minimum complete learner experience over the Phase 1 truth layer:

`onboarding → identity → diagnostic/daily session → safe answer submission → result/reveal → mistake review → progress restoration`

Phase 2 proves that a learner can use the product reliably. It does not yet claim sophisticated adaptation.

## 6. Entry gate

Before implementation begins, verify:

- Phase 1 is merged into `main`.
- Static truth-layer validation passes.
- Supabase/Postgres migration and pgTAP execution status is known.
- If database execution is still unavailable, preserve this as a recorded staging blocker rather than silently assuming success.
- Answer-free learner views exist.
- Publication and correction workflows remain backend-only.

## 7. Required implementation scope

### 7.1 Application foundation

Implement a Cloudflare Workers + Hono TypeScript service, or a comparably portable API structure if repository constraints demand it.

Required boundaries:

- environment validation;
- request IDs;
- structured errors;
- authentication middleware;
- service-role access only inside backend code;
- no service-role secret in browser/mobile bundles;
- API version prefix;
- health and readiness endpoints;
- testable domain services separated from HTTP handlers.

### 7.2 Learner identity

Implement:

- anonymous/local profile identifier;
- authenticated learner profile keyed by `auth.users.id`;
- deterministic anonymous-to-auth attachment;
- idempotent migration record;
- merge-conflict policy when authenticated progress already exists;
- no destructive overwrite of newer server data;
- reinstall and multi-device restoration contract.

The system must treat a changed display name as the same account.

### 7.3 Session model

Add migrations for at least:

- learner profiles;
- anonymous identities or migration records;
- practice sessions;
- immutable session-question snapshots referencing exact `question_version_id`;
- answer attempts;
- answer selections;
- result records;
- bookmarks;
- active-session recovery state;
- idempotency receipts or request records.

A session must be reconstructable after interruption.

### 7.4 Session types

Implement a minimal contract for:

- diagnostic session;
- daily practice session;
- topic practice session.

Full exam simulation remains later unless it is trivial to support without distorting the core.

### 7.5 Safe question delivery

The API must:

- deliver only currently eligible published versions;
- omit canonical answers and explanation bodies before submission;
- snapshot question order and version IDs into the session;
- prevent replacement by later content edits;
- support deterministic pagination/resume;
- reject disputed or suppressed questions for new sessions.

### 7.6 Answer submission

Every submission must contain a client-generated idempotency key.

The backend must:

- authenticate or resolve the learner identity;
- verify the question belongs to the session;
- reject answer changes after finalisation unless the session mode explicitly allows them;
- score only against verified canonical answers;
- record exact question version;
- store elapsed time and client/server timestamps;
- return the previously stored result on duplicate retry;
- prevent a learner from submitting for another learner’s session.

### 7.7 Answer reveal and mistake review

Only after an accepted submission may the backend return:

- correct answer;
- learner selection;
- verified rationale/explanation;
- source/provenance summary appropriate for learners;
- report-question action;
- bookmark action.

The reveal endpoint must not become a generic answer oracle for unattempted questions.

### 7.8 Offline and retry behaviour

Implement:

- client submission IDs;
- duplicate-safe retries;
- monotonic server state;
- clear conflict responses;
- recovery after network interruption;
- no duplicate attempts from repeated sync;
- no answer loss when a response times out after successful server commit.

### 7.9 Basic progress

Phase 2 may show deterministic counts only:

- sessions completed;
- accuracy by broad subject/topic;
- questions awaiting review;
- bookmarks;
- recent activity.

Do not label this as mastery. Phase 3 owns mastery inference.

## 8. Phase 2 API contract

Expected endpoint families, adaptable to the chosen architecture:

- `POST /v1/onboarding`
- `POST /v1/identity/attach`
- `GET /v1/me`
- `POST /v1/practice-sessions`
- `GET /v1/practice-sessions/:sessionId`
- `POST /v1/practice-sessions/:sessionId/answers`
- `POST /v1/practice-sessions/:sessionId/finalize`
- `GET /v1/attempts/:attemptId/review`
- `POST /v1/bookmarks`
- `DELETE /v1/bookmarks/:questionVersionId`
- `POST /v1/question-reports`
- `GET /v1/progress/summary`

The exact OpenAPI contract must be committed and validated.

## 9. Phase 2 blind spots and required tests

### Identity blind spots

- reinstall creates a second learner;
- name mismatch creates a second profile;
- anonymous attachment overwrites existing remote progress;
- repeated attachment duplicates attempts.

### Submission blind spots

- timeout after commit causes a duplicate;
- learner submits a question not in the session;
- answer reveal leaks before submission;
- corrected question changes historical score without an explicit repair process;
- session resumes with a different question version.

### Security tests

- one learner cannot read another learner’s sessions or attempts;
- public clients cannot query canonical answer tables;
- client cannot set score/correctness fields;
- client cannot create a session containing unpublished content;
- service-role key is absent from generated client artifacts and repository history.

## 10. Phase 2 exit gate

Phase 2 is complete only when:

- onboarding and auth attachment are implemented;
- a learner can create, resume, answer, finalise, and review a session;
- duplicate submission returns one stored attempt;
- exact question version is preserved;
- answer reveal is post-submission only;
- reinstall/multi-device restoration has acceptance tests;
- OpenAPI validation passes;
- database/RLS tests pass in an available Supabase environment or remain explicitly blocked in validation records;
- documentation and Phase 3 handoff are merged.

---

# Phase 3 — Deterministic Learner Model

## 11. Mission

Turn attempts into transparent, replayable learning evidence and select the next useful practice set without using opaque AI judgment.

The model must say not only “weak topic,” but also how much evidence supports that claim.

## 12. Entry gate

- Phase 2 merged and session/attempt invariants pass.
- Attempt records are immutable and version-bound.
- Correction-impact handling is specified.
- Enough seeded fixtures exist to test multiple topics, difficulty levels, and time patterns.

## 13. Required implementation scope

### 13.1 Evidence model

Add:

- mastery/evidence events derived from attempts;
- topic-state snapshots;
- algorithm versions;
- replay checkpoints;
- recommendation plans;
- recommendation reasons;
- spaced-revision schedule;
- confidence/uncertainty fields.

Raw attempts remain the source of truth. Derived state must be rebuildable.

### 13.2 Deterministic update algorithm

The first algorithm should use explicit factors such as:

- correctness;
- question difficulty;
- recency;
- repeated-error history;
- answer latency with reasonable caps;
- hint use when Phase 2/3 supports it;
- whether the question was diagnostic, practice, or review;
- content confidence and correction status.

Do not infer deep psychological traits.

### 13.3 Confidence bands

Use learner-facing bands such as:

- insufficient evidence;
- emerging;
- developing;
- secure;
- revision due.

A low sample count must not be presented as confident weakness.

### 13.4 Recommendation engine

A daily set should be assembled from configurable buckets such as:

- weak-topic reinforcement;
- spaced revision;
- current syllabus progression;
- confidence-building items;
- diagnostic exploration.

Selection must consider:

- prior exposure;
- duplicate/near-duplicate avoidance;
- content status;
- difficulty balance;
- session length;
- question-format variety;
- unavailable or disputed items;
- language availability.

### 13.5 Replay and correction

Implement full replay:

- delete or invalidate derived evidence for a learner/algorithm version;
- rebuild from immutable attempts in chronological order;
- account for corrected/suppressed question versions;
- produce deterministic identical results for identical inputs;
- record the reason for any score repair.

### 13.6 Explainability

Every recommendation should expose a non-sensitive reason such as:

- “revision due”;
- “more evidence needed”;
- “recent repeated error”;
- “next syllabus topic”;
- “difficulty progression.”

## 14. Phase 3 API and jobs

Expected contracts:

- `GET /v1/mastery`
- `GET /v1/mastery/:topicId`
- `GET /v1/recommendations/today`
- `POST /v1/recommendations/:planId/start`
- internal replay job;
- correction-impact replay job;
- algorithm-version migration job.

## 15. Phase 3 blind spots and tests

- one wrong answer labels a learner permanently weak;
- many easy duplicates inflate mastery;
- speed is interpreted as knowledge without safeguards;
- corrected questions poison derived state;
- algorithm update silently changes historical dashboards;
- recommendation loop repeatedly serves the same pattern;
- topics with incorrect mappings generate confident bad advice;
- no-content topics cause recommendation failure.

Required tests include deterministic replay, sample-size confidence, correction repair, algorithm version isolation, no experimental content, and recommendation diversity.

## 16. Phase 3 exit gate

- deterministic evidence engine implemented;
- derived state is fully replayable;
- confidence bands are sample-aware;
- next-best-practice sets are generated with recorded reasons;
- correction replay works;
- algorithm versioning works;
- no model provider is required for core mastery;
- API and database tests pass;
- Phase 4 grounding requirements are handed off.

---

# Phase 4 — Grounded Tamil/Bilingual Tutor

## 17. Mission

Explain each mistake clearly in the learner’s preferred language using verified answers and approved source context. The tutor personalises teaching, but it does not decide canonical truth.

## 18. Entry gate

- Phase 3 merged.
- Verified explanations or source excerpts exist for the truth sample.
- Tamil-first versus bilingual policy is selected or explicitly remains experimental.
- A seed terminology glossary exists.
- Model provider credentials are available only in server-side environments, or provider calls remain mock-tested and recorded as an external blocker.

## 19. Required implementation scope

### 19.1 Provider abstraction

Implement a model-neutral interface supporting:

- structured request/response schemas;
- provider/model metadata;
- timeout and retry policy;
- token/cost accounting;
- cancellation;
- mocked provider for deterministic tests;
- no provider-specific format in canonical content tables.

### 19.2 Grounding package

The tutor input must be built from:

- exact question version;
- verified answer;
- learner’s selected answer;
- approved rationale;
- syllabus node;
- approved source excerpts or source identifiers;
- language mode;
- learner explanation level;
- prior misconception evidence only where relevant and privacy-safe.

The model must not be asked to rediscover the official answer when a verified answer exists.

### 19.3 Structured tutor response

Require fields for:

- selected answer summary;
- why it seemed plausible;
- precise misconception;
- why the verified answer is correct;
- compact concept explanation;
- memory aid;
- follow-up retrieval question;
- uncertainty/insufficient-grounding flag;
- source references used.

### 19.4 Validation pipeline

Before serving or caching an explanation:

- answer agreement check;
- source-reference validity;
- no unsupported factual additions;
- terminology/glossary consistency;
- language availability;
- prohibited-claim scan;
- schema validation;
- length/readability limits;
- model disagreement or critic route for high-risk topics.

### 19.5 Caching and cost

Cache by at least:

- question version;
- language mode;
- explanation level;
- prompt/template version;
- model version;
- grounding version.

Track:

- cost per generated explanation;
- cache hit rate;
- generation latency;
- validation failure rate;
- learner usefulness/report rate.

### 19.6 Asynchronous behaviour

The core review screen must always show verified answer and approved baseline rationale. Personalised AI tutoring may load asynchronously and must fail gracefully.

### 19.7 Evaluation harness

Create a fixed evaluation set covering:

- direct MCQ;
- negative wording;
- assertion-reason;
- chronology;
- passage-linked items;
- common Tamil technical terminology;
- plausible distractors;
- insufficient-source cases;
- official/source disagreement cases.

Score factual agreement, naturalness, clarity, misconception handling, source discipline, and unsupported claims.

## 20. Phase 4 blind spots and tests

- fluent Tamil hides a wrong explanation;
- model repeats the right answer without addressing misconception;
- cached explanation survives a corrected question;
- English-shaped Tamil is technically translated but unusable;
- model invents a source citation;
- personalised context leaks another learner’s data;
- provider outage blocks verified review;
- free-tier abuse amplifies inference cost;
- prompt injection inside source/question content controls the tutor.

Required tests include prompt-injection resistance, answer agreement, cache invalidation, provider timeout, cost budget, source validation, and cross-learner isolation.

## 21. Phase 4 exit gate

- provider abstraction and mocked tests pass;
- grounded tutor pipeline works end-to-end with at least one real provider call when credentials are available;
- verified review works without AI;
- explanations are cached and invalidated correctly;
- evaluation harness produces a report;
- Tamil/bilingual human review status is explicit;
- cost budgets are enforced;
- no invented citations or answer disagreement in the acceptance set;
- Phase 5 generation shares validators without bypassing truth controls.

---

# Phase 5 — Controlled Question Generation

## 22. Mission

Generate additional practice inventory without allowing model output to become truth automatically.

The output of a generation model is a **candidate**, not a question available for scoring.

## 23. Entry gate

- Phase 4 merged.
- Truth-layer publication workflow remains the only route to learner-visible content.
- Grounding, schema validation, cost accounting, and provider abstraction exist.
- A reviewed truth sample and evaluation set exist.
- Human or qualified review capacity is identified for high-risk content.

## 24. Required implementation scope

### 24.1 Generation specifications

A generation job must specify:

- exam and syllabus version;
- primary topic/micro-skill;
- cognitive skill;
- question format;
- difficulty target;
- language mode;
- source/grounding requirements;
- desired distractor logic;
- prohibited ambiguity;
- expected solving time;
- risk tier;
- requested candidate count.

### 24.2 Candidate isolation

Generated candidates must live in a quarantined state or table. They cannot:

- appear in learner views;
- affect mastery;
- be selected for sessions;
- be published by the generating service;
- overwrite canonical versions.

### 24.3 Multi-stage pipeline

Implement:

`coverage gap → generation specification → candidate generation → independent solve/critic → deterministic validators → duplicate search → language check → risk scoring → editorial review → truth-layer publication`

The generator and independent solver should not share hidden answer assumptions where avoidable.

### 24.4 Deterministic validators

At minimum detect:

- missing or duplicate options;
- nonexistent correct option;
- multiple correct answers when only one is allowed;
- explanation/answer contradiction;
- negative-wording mistakes;
- “all/none of the above” inconsistency;
- option-length or answer-position leakage;
- unsupported dates/statistics;
- malformed formula/table/structured payload;
- passage-question inconsistency;
- exact and near duplicates;
- translation mismatch;
- answer distribution imbalance;
- source absence for medium/high-risk facts;
- prohibited current-affairs staleness.

### 24.5 Risk tiers

- **Low:** stable definitions, vocabulary, simple arithmetic.
- **Medium:** application, chronology, multi-statement, passage interpretation.
- **High:** current affairs, law/policy, contested history, changing statistics/officeholders, complex quantitative work.

High-risk candidates require dated authoritative grounding and human approval. A configuration flag should allow high-risk generation to be disabled entirely.

### 24.6 Duplicate and coverage engine

Compare against:

- canonical published content;
- archived/corrected content;
- other candidates;
- semantically similar stems;
- same answer/distractor pattern;
- shared passage reuse.

Coverage reports must count reviewed unique skills, not raw generated volume.

### 24.7 Shadow mode

Before generated questions can enter normal publication review:

- run generation silently;
- retain all candidates and validator evidence;
- manually review a representative sample;
- calculate serious-defect rate;
- compare independent solver agreement;
- measure review minutes per publishable item;
- confirm unit economics;
- define rollback and kill-switch operation.

### 24.8 Operational console or queue

Implement the minimum editorial queue needed to:

- inspect candidate and source context;
- see every validator result;
- compare independent answers;
- edit by creating a reviewed canonical version;
- approve/reject with reason;
- bulk suppress a generation run;
- trace provider/model/prompt version.

A full design-system-heavy admin product is not required, but operational review cannot remain a raw SQL-only bottleneck if shadow testing needs real reviewers.

## 25. Phase 5 blind spots and tests

- generator and critic repeat the same error;
- model creates two defensible answers;
- near-duplicates inflate apparent coverage;
- option patterns reveal the answer;
- translated stem and answer diverge;
- source text contains prompt injection;
- generated content reaches learner sessions through a forgotten query;
- correction does not invalidate generated explanation caches;
- generation costs continue when no review capacity exists;
- reviewer fatigue reduces defect detection;
- a model/version change silently shifts quality.

Tests must prove quarantine, kill switch, no learner visibility, validator failure routing, duplicate detection, source requirements, risk-tier enforcement, and publication only through Phase 1 controls.

## 26. Phase 5 exit gate

- generation specifications are versioned;
- candidates are quarantined;
- critic/independent solve and validators run;
- duplicate detection works;
- risk-tier policy is enforced;
- editorial review flow exists;
- shadow-mode quality report exists;
- kill switch is tested;
- serious-defect and review-cost thresholds are defined;
- no generated item reaches learner views without truth-layer publication;
- production release gate packet is complete.

---

# Production Release Gate — Not a Separate Phase

## 27. Purpose

After Phase 5, implementation completeness does not automatically mean public launch readiness. The following cross-phase gate must pass.

## 28. Required evidence

### Product and learner

- launch wedge validated or formally changed;
- Tamil-first/bilingual preference tested;
- 30–50-question truth sample reviewed;
- seven-day pilot completed;
- repeated-error reduction and return behaviour measured;
- learner distrust reasons reviewed.

### Content

- serious-defect threshold met;
- correction and suppression rehearsed;
- official/source hierarchy exercised;
- current-affairs content disabled unless its separate dated pipeline is ready.

### Security and privacy

- RLS and cross-user tests pass in staging;
- service-role secret handling verified;
- account deletion/export policy implemented or scheduled before collection expands;
- threat models reviewed;
- dependency and secret scans pass;
- rate limits and abuse budgets enabled.

### Reliability

- migrations run against target Supabase/Postgres version;
- backup/restore rehearsal;
- idempotent sync test under network failure;
- model outage test;
- correction replay test;
- observability and alerting configured.

### Economics

- cost model at 100, 1,000, and 10,000 active learners;
- inference budgets;
- review minutes per item;
- plausible positive contribution margin for at least one pricing configuration.

## 29. Release decisions

- **LAUNCH:** all critical gates pass; medium risks have owners and deadlines.
- **LIMITED PILOT:** core safety passes, but market/content scale evidence remains incomplete.
- **PIVOT:** wedge, language, or core job changes; constitution and roadmap are updated first.
- **STOP:** no credible trust path, repeated learner pain, or sustainable economics.

---

## 30. Definition of autonomous success

A future `build` is successful only when:

1. The target phase is implemented according to this document.
2. The roadmap validator passes.
3. Tests and negative tests are documented truthfully.
4. The implementation is committed and pushed on a dedicated branch.
5. A PR is opened and inspected.
6. The PR is merged into `main`.
7. The merged `main` commit is fetched and confirmed.
8. `phase-status.json` records the PR and merge commit.
9. Remaining blockers are explicit.
10. The next phase has a clear, machine-readable status.

This process prevents a common failure mode: impressive code that is neither safely integrated nor verifiably complete.