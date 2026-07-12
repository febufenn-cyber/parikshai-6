# Parikshai Phase 0 — Product Constitution and Validation Gate

**Status:** implemented as a strategic foundation; external validation remains open.

This document is the controlling Phase 0 artifact. Locked rules protect content trust, learner identity, and system integrity. Market choices are explicitly provisional until interviews and prototype behaviour satisfy the Phase 1 entry gate.

## Contents

1. Product constitution
2. Launch wedge and first learner
3. Content trust and AI authority
4. Tamil-first language style
5. Syllabus ontology
6. Identity and data
7. Economics, analytics, and experiments
8. Assumptions, risks, and decisions
9. Phase 1 entry gate

---

# 1. Product constitution

## Mission

Parikshai helps an exam aspirant practise the next most useful material and understand every mistake in clear, trustworthy language.

## Initial product promise

> Practise what you need. Understand every mistake.

The working learner-facing promise is:

> Parikshai gives you a focused daily practice set, explains each mistake in clear Tamil, and adapts later practice to weak topics.

This wording is provisional until learner research tests whether the daily-plan problem is stronger than mock analysis, doubt solving, or another adjacent job.

## Strategic principles

1. **Trust before volume.** A smaller verified bank beats unlimited questionable generation.
2. **Learning before engagement.** Optimise repeated-error reduction and retention of knowledge, not time spent.
3. **Evidence before expansion.** One exam-language loop must work before adding another.
4. **Explain uncertainty.** Weakness scores and generated content must never present false certainty.
5. **Preserve provenance.** Every public question and explanation is traceable and versioned.
6. **Keep the core model-independent.** Canonical content and learner history cannot depend on one provider.
7. **Design for intermittent connectivity.** A model outage must not erase or block a practice session.
8. **Corrections repair learning state.** When an answer changes, affected attempts and mastery are recalculated.
9. **Identity survives reinstall.** Names and onboarding fields never define ownership.
10. **Human review is a product capability.** The internal editorial workflow is part of the moat.

## First complete loop

1. Select exam and language.
2. Complete a short diagnostic.
3. Receive a ten-question daily practice set.
4. Submit answers without waiting for AI.
5. Review mistakes with verified answer and grounded explanation.
6. Update topic evidence and confidence.
7. Recommend the next practice set.
8. Resume on any device after authentication.

## Opening non-goals

- More than one public exam family
- More than one primary teaching language
- Live unreviewed generated questions
- Current-affairs automation before static-content trust works
- Teacher marketplace or live classes
- Public social feed or chat community
- Rank/selection guarantees
- Exact readiness predictions from insufficient data
- Voice as a dependency
- Separate native business logic per client

## Expansion rule

A second exam or language requires:

- repeat usage in the first wedge;
- low serious-content-defect rate;
- sustainable contribution margin;
- repeatable content operations;
- a reachable distribution channel;
- no unresolved identity or progress-loss defects.

## Kill or reposition signals

Reconsider the wedge when learners do not repeatedly use the daily loop, sourced explanations fail to earn trust, reliable content cannot be produced economically, or the product is not meaningfully better than existing PDFs/Telegram flows.

---

# 2. Launch wedge and first learner

## Provisional wedge

**TNPSC Group IV, Tamil-first with bilingual technical terminology.**

This is a product hypothesis, not a completed market conclusion. The existing UGC-NET corpus remains an internal proving ground for schemas, rendering, attempt replay, mastery, and regression tests; it does not determine the public brand.

## Why this opening is attractive

- The vernacular teaching proposition is central rather than cosmetic.
- Daily mobile practice is plausible for learners studying around work, college, or family duties.
- Official papers and syllabus structure can anchor a truth layer.
- Regional YouTube and Telegram communities provide testable distribution routes.
- Group IV is a narrower opening than “all government exams.”

## What could make this the wrong move

- Learners may value full mock analysis more than daily practice.
- Tamil-first may be less useful than bilingual explanations.
- The review burden across general studies may be too high.
- Existing apps may already solve the core job adequately.
- UGC-NET may show materially stronger founder advantage and willingness to pay.

## First-learner hypothesis

A Tamil-speaking, mobile-first TNPSC Group IV aspirant preparing independently or alongside low-cost coaching who:

- studies in fragmented sessions;
- uses YouTube, Telegram, PDFs, or question-bank apps;
- has difficulty choosing the next useful practice;
- sees answer keys without understanding the misconception;
- needs progress to survive reinstall or device change;
- is price-sensitive and intolerant of obvious answer defects.

## Jobs to test

Rank these from observed behaviour, not opinions:

1. Decide what to practise today.
2. Understand why an answer is wrong.
3. Detect and revise weak topics.
4. Complete realistic timed mocks.
5. Keep materials and progress in one place.
6. Practise effectively in Tamil/bilingual language.

## Wedge comparison scorecard

Score TNPSC Group IV, TNPSC Group II, and UGC-NET English from 1–5 against:

| Criterion | Weight |
|---|---:|
| Founder/data advantage | 20% |
| Repeated learner pain | 15% |
| Vernacular differentiation | 15% |
| Reliable content availability | 15% |
| Distribution access | 10% |
| Trusted MVP feasibility | 10% |
| Willingness to pay | 10% |
| Content/regulatory risk | 5% |

The decision log must retain rejected alternatives and the evidence used.

## Pilot cohort

Recruit a mixed cohort rather than only friends:

- first-time aspirants;
- repeat aspirants;
- employed learners;
- college-age learners;
- Tamil-medium and English-medium backgrounds;
- at least two tutors or successful candidates as expert reviewers.

Interview commitments and real prototype usage count as evidence. Compliments do not.

---

# 3. Content trust and AI authority

## Content classes

| Class | Meaning | May affect scored mastery? |
|---|---|---|
| A — Official | Official paper and final key/authoritative government source | Yes |
| B — Curated | Human-written or human-reviewed against authoritative material | Yes |
| C — AI-assisted | AI drafted, independently reviewed and approved | Yes, after approval |
| D — Experimental | Generated candidate or unresolved item | No |

The learner UI may simplify labels, but internal systems must never merge these classes invisibly.

## Truth hierarchy

1. Official final answer key
2. Applicable official notification, statute, syllabus, or government publication
3. Prescribed/authoritative source
4. Qualified reviewer decision with recorded rationale
5. Reputable secondary source
6. Model reasoning

A model may flag a possible official error, but cannot silently replace the official key.

## Minimum publication contract

Every scored question requires:

- stable question ID and immutable version ID;
- exam and syllabus mapping;
- question type and structured payload;
- source/provenance;
- correct answer;
- explanation or approved rationale;
- original language and translation metadata;
- review status and reviewer;
- rendering validation;
- publication and, where relevant, expiry dates.

## Correction workflow

`reported → triaged → suppressed if severe → reviewed → corrected/versioned → affected attempts identified → mastery recalculated → learner notice when material`

Never edit history in place. Attempts retain the exact version shown.

## AI may

- draft explanations and translations;
- suggest syllabus tags and distractors;
- detect possible duplicates and contradictions;
- create candidate questions;
- generate a personalised teaching wrapper around verified facts;
- summarise learner patterns without changing canonical attempts.

## AI may not

- override official truth silently;
- publish high-risk content without validation;
- invent citations or sources;
- create undated changing facts for scored use;
- merge learner identities;
- mutate canonical content without a version;
- penalise mastery using Class D items;
- claim official authority;
- hide uncertainty or validator disagreement.

## Generation pipeline

`coverage gap → written generation specification → candidate model → independent solver/critic → deterministic validators → duplicate search → language check → risk tier → reviewer/approval → publication`

Direct `request → generate → score learner` is prohibited.

## Risk tiers

- **Low:** stable definitions, basic vocabulary, simple arithmetic.
- **Medium:** application, chronology, passage, multi-statement.
- **High:** current affairs, law/policy, contested history, complex quantitative work, changing officeholders/statistics.

High-risk items require authoritative dated grounding and human approval.

## Required model metadata

Store provider, model/version, prompt/template version, timestamp, source context IDs, validator outcomes, reviewer, and final disposition.

---

# 4. Tamil-first language style guide

Status: **draft to be tested with learners and Tamil subject reviewers.**

## Goal

Teach naturally in Tamil without forcing unnatural translations of familiar exam terminology.

## Supported presentation modes

1. **Tamil-first:** Tamil sentence structure; essential English term in brackets on first use.
2. **Bilingual:** Tamil explanation with common English technical terms retained.
3. **English:** available for learners who prefer English but want Tamil support selectively.

Phase 0 must compare comprehension and preference across the first two modes.

## Voice

- respectful, direct, calm, and exam-focused;
- conversational enough to understand, not slang-heavy;
- never shame a learner for a mistake;
- explain the misconception before repeating the correct answer;
- use short paragraphs and one concept per step.

## Explanation structure

1. `நீங்கள் தேர்ந்தெடுத்தது` — selected answer.
2. `அது சரியாகத் தோன்றும் காரணம்` — why it looked plausible.
3. `ஆனால் இங்கு தவறு` — precise misconception.
4. `சரியான பதில்` — verified answer and reason.
5. `நினைவில் வைக்க` — compact memory aid.
6. One follow-up retrieval question.

## Terminology rules

- Maintain a versioned subject glossary.
- Prefer terminology used in official Tamil materials where clear.
- Retain widely used English terms in brackets.
- Do not translate proper nouns, institution names, article numbers, or legal titles inconsistently.
- Do not alternate synonyms merely for stylistic variety.
- Preserve numerals, units, formulae, tables, and option labels exactly unless the content specification says otherwise.
- Record transliteration separately from translation.

## Quality checks

A Tamil explanation must be reviewed for:

- factual agreement with the verified answer;
- naturalness;
- syllabus relevance;
- technical-term consistency;
- reading difficulty;
- absence of English-shaped Tamil sentence structure;
- no extra unsupported facts;
- correct treatment of negative wording such as “not/incorrect.”

## Glossary record

Each entry should contain:

`concept_id, English term, preferred Tamil, acceptable alternatives, retain English?, subject, source, reviewer, version, notes`

No mass translation begins until a seed glossary for launch subjects is approved.

---

# 5. Syllabus ontology

## Purpose

The ontology is the shared contract for content coverage, mastery, analytics, and generation. Incorrect tagging creates confidently wrong personalisation.

## Hierarchy

`exam → exam_version → paper → subject → unit → topic → micro_skill`

Questions also receive independent cognitive and format tags.

Example skeleton:

`TNPSC Group IV → applicable syllabus version → General Studies → Indian Polity → Constitution → Fundamental Rights → identify applicable principle/article`

The exact official hierarchy must be imported and cited from the applicable official syllabus before scored publication.

## Mapping rules

- Every scored question has exactly one primary syllabus node.
- Secondary nodes are optional and evidence-weighted less strongly.
- Topic, cognitive skill, and question format are separate dimensions.
- Shared passages and instructions are first-class entities, not copied strings.
- Syllabus versions are immutable; mappings may be superseded, not overwritten.
- Current-affairs nodes require relevance start/end dates.
- Questions outside the applicable syllabus are excluded or explicitly labelled enrichment.
- Mapping confidence and reviewer are stored.

## Cognitive tags

At minimum:

- recall;
- comprehension;
- application;
- analysis;
- comparison;
- sequencing/chronology;
- calculation;
- interpretation.

## Format tags

At minimum:

- direct MCQ;
- multi-statement/coded response;
- assertion-reason;
- match;
- passage-linked;
- table/data interpretation;
- chronology;
- numerical;
- image/diagram;
- multi-select.

## Coverage reporting

Coverage must distinguish:

- number of questions;
- number of reviewed questions;
- difficulty distribution;
- cognitive distribution;
- recent learner exposure;
- serious-defect rate.

A topic is not “covered” merely because it has many near-duplicate questions.

---

# 6. Identity and data policy

## Canonical identity

The permanent learner key is the Supabase authenticated user ID (`auth.users.id`).

Never use name, email display name, phone display name, preferred language, device ID, or onboarding answers as account ownership keys.

## Pre-auth onboarding

1. Create a temporary local/anonymous profile ID.
2. Record local practice against that temporary ID.
3. On sign-in, resolve whether the authenticated account already has progress.
4. Offer deterministic migration/merge; do not duplicate silently.
5. Preserve an auditable migration record.
6. Make retries idempotent.
7. Never overwrite newer remote progress with stale device data.

## Reinstall and multi-device requirements

- Signing into the same auth account restores attempts, bookmarks, mastery evidence, settings, and active-session recovery state.
- A changed learner name has no effect on identity.
- Offline attempts receive client-generated idempotency keys and sync safely.
- Conflict rules are explicit and tested.
- Mock timers and answer state survive interruption according to exam-mode rules.

## Content/version references

Every attempt references:

- learner ID;
- question ID;
- exact question version;
- session ID;
- answer payload;
- timestamp;
- elapsed time;
- mode;
- sync/idempotency key;
- scoring status.

## Privacy baseline

Before production, document:

- collected fields and purpose;
- analytics consent;
- raw model-context retention;
- account export and deletion;
- retention periods;
- treatment of minors;
- access boundaries for future coaching dashboards;
- RLS policies and service-role usage.

## Non-negotiable tests

- onboarding → sign-in → progress attached;
- reinstall → sign-in → progress restored;
- changed name → same account;
- duplicate sync → one attempt;
- existing-account merge → no silent loss;
- question correction → attempt history retained and score recalculated safely.

---

# 7. Economics, analytics, and experiments

## Economic rule

Do not promise unlimited AI usage before measuring contribution margin.

For each paid learner:

`revenue − taxes/payment fees − infrastructure − inference/TTS − content review allocation − support allocation − acquisition/refund allocation = contribution margin`

## Cost controls

- Cache explanations by question version, language, level, and model/template version.
- Pre-generate common verified explanations.
- Personalise only the wrapper that truly needs learner context.
- Use smaller models for classification/formatting and stronger models for high-risk review.
- Batch generation and evaluation.
- Place free-tier inference behind explicit budgets.
- TTS is optional and cached; it is not part of the core dependency.
- Track human review minutes per publishable item.

## Pricing hypotheses to test

- monthly subscription;
- three-month exam-cycle pack;
- one-time exam pack;
- free daily practice with paid adaptive plan/mocks;
- verified bank free, personalised tutoring paid.

The original `$2–5/month` is a hypothesis, not a commitment.

## Core event contract

At minimum:

- onboarding_started/completed;
- diagnostic_started/completed;
- practice_session_created/started/completed/abandoned;
- question_viewed;
- answer_selected/changed/submitted;
- explanation_opened;
- followup_answered;
- question_reported;
- bookmark_changed;
- mastery_evidence_updated;
- recommendation_shown/opened;
- reminder_delivered/opened;
- auth_link_started/completed/failed;
- anonymous_progress_migrated;
- subscription_started/cancelled/refunded.

Events carry schema version, learner/session IDs, client time, server time, app version, exam, language, mode, and question version where applicable.

## Learning metrics

Prioritise:

- repeated-error reduction;
- seven-day retention of previously corrected concepts;
- diagnostic-to-later accuracy change;
- completion and return rate;
- explanation usefulness;
- serious question-report rate;
- mastery calibration and confidence interval;
- time-management improvement in mocks.

Do not treat time spent, raw question count, or streak length as proof of learning.

## Phase 0 experiments

1. Interview existing behaviour; do not ask only whether users “like AI.”
2. Compare Tamil-first, bilingual, and English explanation comprehension.
3. Test a clickable/manual daily loop with a reviewed sample.
4. Test whether learners return for seven days without prizes.
5. Test a commitment signal: pilot signup, community access, or refundable early access.
6. Estimate costs at 100, 1,000, and 10,000 active learners.

---

# 8. Assumptions, risks, and decision log

## Assumptions ledger

| ID | Assumption | Confidence | Evidence required |
|---|---|---:|---|
| A01 | TNPSC Group IV is the strongest public wedge | Low | weighted alternatives + interviews + channel access |
| A02 | daily next-best practice is a repeated pain | Low | observed routines and prototype return |
| A03 | Tamil/bilingual explanations improve understanding | Low | comprehension comparison |
| A04 | sourced AI-assisted explanations can earn trust | Low | blind quality test and report rate |
| A05 | ten questions is an acceptable daily session | Low | completion and qualitative feedback |
| A06 | a paid plan can cover review and inference | Low | unit model and payment commitment |
| A07 | Telegram/YouTube can recruit the first cohort | Low | one cooperative channel and conversions |
| A08 | existing UGC-NET assets accelerate engine validation | Medium | fixture/regression reuse demonstrated |

## Risk register

| Risk | Severity | Prophylaxis |
|---|---:|---|
| Wrong or ambiguous answer destroys trust | Critical | provenance, versioning, review, suppression, correction replay |
| Unnatural Tamil | High | glossary, three-mode test, human language review |
| False weak-topic certainty | High | evidence thresholds and confidence bands |
| Review operation becomes bottleneck | High | measure review minutes; risk-tier workflow |
| Live model dependency blocks practice | High | cached/verified core and async jobs |
| Reinstall loses progress | Critical | auth-ID ownership and migration tests |
| Expansion hides weak retention | High | hard expansion gate |
| Current affairs become stale | High | dated sources, expiry, separate pipeline |
| Inference/review cost exceeds price | High | budgets, caching, pricing experiments |
| Generated items leak into scored bank | Critical | separate states/tables and kill switch |
| Official/source disagreement | High | truth hierarchy and visible dispute status |
| Low-connectivity failure | Medium | resumable sessions, small payloads, offline sync |

## Decision log

| Date | Decision | Status | Revisit trigger |
|---|---|---|---|
| 2026-07-12 | Use TNPSC Group IV Tamil-first as provisional public wedge | Provisional | evidence favours another wedge |
| 2026-07-12 | Use UGC-NET corpus only as internal proving ground initially | Provisional | public demand clearly stronger |
| 2026-07-12 | Verified content precedes public generation | Locked | never without equivalent trust control |
| 2026-07-12 | AI cannot silently override official truth | Locked | never |
| 2026-07-12 | `auth.users.id` owns permanent progress | Locked | only platform migration |
| 2026-07-12 | No second exam before first-wedge gates | Locked | Phase 1+ evidence passes |

Append decisions; do not rewrite history.

---

# 9. Phase 1 entry gate

Phase 1 builds the canonical truth layer. Engineering may prototype earlier, but scored-content implementation must not be declared Phase 1-ready until blocking gates pass.

## Blocking gates

### Wedge and learner

- [ ] TNPSC Group IV remains the best-supported wedge after alternatives are scored.
- [ ] Interviews include first-time and repeat aspirants, Tamil- and English-medium backgrounds.
- [ ] Repeated current behaviour confirms a high-frequency problem.
- [ ] At least one concrete pilot cohort/channel is committed.
- [ ] The first product promise is understood without explanation.

### Language

- [ ] Tamil-first and bilingual explanation modes are tested.
- [ ] Preferred mode is selected from comprehension, not aesthetics.
- [ ] Seed glossary is reviewed for launch subjects.
- [ ] At least two qualified Tamil reviewers agree on the editorial workflow.

### Content

- [ ] Applicable official syllabus/version is archived and mapped at top levels.
- [ ] 30–50 varied questions satisfy the publication contract.
- [ ] Official, curated, AI-assisted, and experimental states are demonstrated.
- [ ] Correction/version replay is specified.
- [ ] Complex question types render in the prototype.
- [ ] Serious defect criteria and suppression SLA are defined.

### Product evidence

- [ ] Learners complete diagnostic → daily set → explanation → next-plan flow.
- [ ] No facilitator is required to explain the UI.
- [ ] A seven-day manual/clickable pilot has measurable returns.
- [ ] Explanation usefulness and distrust reasons are recorded.
- [ ] The ten-question session size is accepted or replaced by evidence.

### Identity and data

- [ ] Anonymous-to-auth merge contract is approved.
- [ ] Reinstall/multi-device acceptance tests are written.
- [ ] Attempt idempotency and question-version references are specified.
- [ ] Privacy/data-retention baseline is documented.

### Economics

- [ ] Cost model exists for 100, 1,000, and 10,000 active learners.
- [ ] Human review minutes per item are measured on the truth sample.
- [ ] At least one pricing/free-tier configuration has plausible positive contribution margin.
- [ ] AI and TTS budgets are explicit.

## Decision

- **PROCEED:** all blocking gates pass; unresolved risks have owners and dates.
- **PIVOT:** core job or wedge changes; update constitution and decision log first.
- **STOP:** no repeated pain, no credible trust path, or no plausible economics.

Approval record:

`date / reviewer / decision / unresolved exceptions / next phase owner`
