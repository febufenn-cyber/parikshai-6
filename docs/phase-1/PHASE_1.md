# Parikshai Phase 1 — Canonical Truth Layer

**Engineering status:** implemented foundation.

**Market status:** not yet declared Phase 1-ready. The Phase 0 learner, language, pilot, and economics gates remain blocking for public scored launch.

## 1. Mission

Phase 1 creates the system of record for exam content. It must answer, for every learner-visible item:

- What exact question version did the learner see?
- Which exam and syllabus version does it belong to?
- Where did the question and answer come from?
- Who or what reviewed it?
- Is it allowed to affect scoring and mastery?
- Can it be suppressed immediately?
- If corrected, which attempts and mastery records are affected?

The truth layer is not a question bank table. It is an auditable publishing system.

## 2. Kasparov position evaluation

### Obvious move

Create a `questions` table and start importing content.

### Hidden tactical loss

A single mutable question row makes it impossible to reconstruct what a learner saw after an edit. It also allows generated, unreviewed, or disputed content to leak into scored sessions.

### Prophylactic move

Separate stable question identity from immutable versions, enforce publication through one controlled database function, preserve provenance and reviews, and record corrections as links between versions.

### Endgame advantage

The same model supports official papers, curated material, AI-assisted drafts, multiple languages, dispute handling, attempt replay, and future mastery recalculation without replacing the data model.

## 3. Scope

Phase 1 engineering includes:

1. Exam and immutable exam-version records.
2. Versioned syllabus ontology.
3. Source documents with hashes and effective dates.
4. Stable questions and immutable question versions.
5. Structured options, passages, assets, answers, and multilingual explanations.
6. Primary and secondary syllabus mappings.
7. Editorial reviews and validator results.
8. Controlled publication and suppression.
9. Question reports and correction-impact records.
10. Row-level security separating learners from editorial operations.
11. Fixture validation and database contract tests.

Phase 1 does **not** include:

- learner attempts or mastery computation;
- live question generation;
- current-affairs automation;
- a full editorial web interface;
- billing;
- mock sessions;
- public multi-exam expansion.

## 4. Core invariants

These rules are enforced in the migration, not left as documentation-only promises.

### Identity and history

- `questions.id` is the stable conceptual identity.
- `question_versions.id` is the exact immutable learner-visible version.
- Versions have monotonically increasing `version_number` within a question.
- A correction creates a new version linked through `supersedes_version_id`.
- Published content payloads cannot be edited in place.

### Publication

- Experimental content cannot be published.
- A version cannot be published without an answer verification timestamp.
- A version cannot be published without verified explanation coverage.
- A version cannot be published without language and rendering review.
- A version cannot be published without at least one source.
- A version cannot be published without exactly one primary syllabus mapping.
- Choice-based formats require at least two options.
- Every declared correct option key must exist.
- Direct updates to `status = 'published'` are blocked; publishing uses `content.publish_question_version`.

### Learner safety

- Learners can read only currently valid published content.
- Learners cannot write to canonical content tables.
- Experimental, disputed, expired, or future-dated versions are hidden from normal learner reads.
- Reports can suppress a version without destroying history.

### Auditability

- Reviews, publication events, validator results, and correction links are append-only.
- Model/provider metadata is stored for generated or AI-assisted content.
- Source hashes permit later verification that the underlying source has not changed.

## 5. Data model

### Reference layer

- `content.exams`
- `content.exam_versions`
- `content.syllabus_nodes`
- `content.source_documents`

### Canonical content layer

- `content.passages`
- `content.questions`
- `content.question_versions`
- `content.question_options`
- `content.question_assets`
- `content.question_syllabus_mappings`
- `content.question_sources`
- `content.explanations`

### Quality and operations layer

- `content.content_reviews`
- `content.generation_runs`
- `content.validator_results`
- `content.question_reports`
- `content.corrections`
- `content.publication_events`
- `content.staff_users`

## 6. Lifecycle

Normal editorial flow:

`imported → structurally_valid → answer_verified → explanation_verified → language_reviewed → publishable → published`

Exceptional states:

- `published → disputed` when a credible defect is reported;
- `published/disputed → corrected` when a successor version is approved;
- any non-terminal state may become `archived`;
- disputed content may be republished only after a recorded review and unchanged payload.

Status does not replace evidence. Verification timestamps, reviews, validators, sources, and mappings remain independently queryable.

## 7. Publishing contract

`content.validate_question_version(version_id)` returns a row for every publication rule with:

- `rule_code`;
- boolean `passed`;
- human-readable `details`.

`content.publish_question_version(version_id)`:

1. requires a reviewer or administrator staff role;
2. locks the candidate version;
3. requires `status = 'publishable'` or a disputed version being republished;
4. executes all publication rules;
5. rejects on any failed rule;
6. marks a previously published sibling as corrected when appropriate;
7. publishes the candidate;
8. moves the stable question's current pointer;
9. appends a publication event.

No API route should reimplement these rules in application code.

## 8. Correction protocol

When an answer or materially learner-visible payload changes:

1. mark the old version disputed when severity requires suppression;
2. create a new version with `supersedes_version_id = old_version_id`;
3. rerun structural, answer, explanation, language, and rendering review;
4. publish the successor through the publication function;
5. insert `content.corrections` with reason and impact status;
6. Phase 2 attempt services later identify affected attempts;
7. recalculate scoring and mastery from the original version references;
8. notify materially affected learners.

A typo that does not alter meaning still creates a new version after publication. The cost of versioning is lower than the cost of unverifiable history.

## 9. Content-class rules

| Class | Meaning | Publishable? | Can affect mastery? |
|---|---|---:|---:|
| `official` | Official paper/key or authoritative government material | Yes | Yes |
| `curated` | Human-authored or reviewed against authoritative sources | Yes | Yes |
| `ai_assisted` | AI drafted, independently reviewed and approved | Yes | Yes |
| `experimental` | Candidate, unresolved, or shadow-evaluation item | No | No |

Content class never changes merely to bypass a failed validation. A newly reviewed candidate receives a successor version with the correct audit trail.

## 10. Question payload contract

`question_versions.prompt`, `answer_payload`, and `shared_payload` are JSONB because formats differ, but the surrounding relational contract prevents an unstructured blob system.

Required application conventions:

- localized text is an object keyed by BCP-47-like language code (`ta`, `en`, etc.);
- choice answers use `answer_payload.correct_option_keys`;
- numerical answers use an explicit value, tolerance, and unit contract;
- shared passages are stored once and linked by `passage_id`;
- image/table resources are first-class assets with checksums and alt text;
- option keys are stable inside a version and independent of display labels;
- raw model responses are never the canonical payload.

## 11. Syllabus mapping

Every publishable version has exactly one primary mapping. Secondary mappings are allowed.

Mappings store:

- immutable syllabus-node ID;
- primary/secondary role;
- confidence;
- cognitive tag;
- mapping reviewer;
- timestamp.

Topic, cognitive skill, and question format remain separate dimensions. Coverage dashboards must count reviewed diversity, not only raw volume.

## 12. Source and provenance rules

A source record includes:

- source kind;
- issuer;
- title;
- URI or storage locator;
- SHA-256 where bytes are available;
- publication/effective dates;
- final-key flag;
- structured metadata.

`question_sources` records the exact locator and whether the source supports the question text, answer, explanation, or multiple claims.

A model's reasoning is never represented as an authoritative source.

## 13. Editorial roles

- `editor`: imports, structures, and drafts content.
- `reviewer`: performs quality decisions and may publish.
- `admin`: manages staff and may publish or suppress.

The learner-facing application must never hold service-role credentials. Editorial writes run through a trusted backend/service role, while reviewer workflow functions require an authenticated staff identity.

## 14. RLS boundary

Anonymous and authenticated learners may read only the dedicated API views:

- active exams and applicable exam versions;
- published syllabus nodes;
- stable questions with a currently published version;
- the currently valid published version and its options.

They may not query canonical base tables directly. In particular, `answer_payload` and verified explanations are backend-only until the application has accepted an answer. They also may not read:

- experimental drafts;
- staff notes;
- raw validator details that expose internal systems;
- model prompt/context payloads;
- unresolved reports;
- unpublished successor versions.

Staff workflow functions are role-gated through `content.staff_users` and `auth.uid()`.

## 15. Operational views

The migrations expose:

- `content.api_exams` and `content.api_syllabus_nodes` for safe discovery;
- `content.api_published_questions` for learner-safe, answer-free question retrieval;
- `content.editorial_queue` for items awaiting the next required review;
- `content.coverage_summary` for reviewed syllabus coverage and class/status counts.

Learner-safe views are security-barrier interfaces containing only explicitly approved columns and published rows. Canonical base tables remain RLS-protected and are not granted to learner roles. Editorial CRUD runs through a trusted backend/service role; reviewer workflow functions still verify `auth.uid()` against `content.staff_users`.

## 16. Serious defects and suppression

Critical defect examples:

- wrong official answer;
- multiple valid answers where only one is accepted;
- mistranslation changing meaning;
- source mismatch;
- broken passage/option binding;
- published experimental content;
- stale changing fact presented as current.

Target operational response:

- critical: suppress as soon as confirmed, target under 4 hours;
- high: triage under 1 business day;
- normal: review in the next editorial batch.

The current migrations provide the state and event model. Alerting and staffing SLAs are later operational work.

## 17. Validation strategy

### Repository checks

`npm test` runs the dependency-free fixture validator. It checks IDs, states, localized payloads, option uniqueness, answer-option consistency, provenance, and the experimental-content quarantine.

### Database checks

`supabase test db` runs pgTAP contract tests covering:

- required tables and functions;
- experimental publication failure;
- missing-source and missing-primary-mapping failures;
- direct publication update rejection;
- published and child-payload immutability;
- successor-version correction structure;
- current-published pointer integrity.

### Manual review

The 30–50 question truth sample must include complex formats and be previewed on target mobile widths before public use.

## 18. Blind spots deliberately handled

### “Verified” as one boolean

A single boolean cannot distinguish answer, explanation, language, rendering, and source review. The schema records separate evidence.

### Published edits

Editing a row after learners answer it destroys replay. Published payloads and their options, mappings, sources, explanations, passages, and assets are immutable.

### Answer leakage through Supabase

RLS filters rows, not sensitive columns. Learner roles therefore receive only answer-free security-barrier views; they never receive direct canonical table grants.

### One source per question

A question may derive text, answer, and explanation from different authoritative locations. Provenance is many-to-many with claim roles.

### Translation drift

Translations and explanations are version-bound. A corrected original cannot silently leave an old translation attached.

### Duplicate official questions

Stable identity and source locators allow duplicate detection without deleting legitimately repeated official appearances.

### Stale content

Versions support `valid_from`, `valid_until`, and `expires_at`. Learner reads exclude expired content.

### Service-role leakage

Learner clients never receive service-role credentials. Canonical CRUD belongs behind the API boundary.

### AI provider lock-in

Generation metadata is auxiliary. Canonical payloads are provider-neutral.

## 19. Phase 1 implementation deliverables

- [x] Phase 1 architecture and operational contract.
- [x] Supabase/Postgres migrations.
- [x] Publication validation function.
- [x] Controlled publish, suppression, and archive functions.
- [x] Immutable published-version and child-payload triggers.
- [x] Status-transition enforcement.
- [x] RLS and answer-free learner-safe views.
- [x] Question reporting and correction records.
- [x] Dependency-free fixture validation.
- [x] CI workflow for fixture validation.
- [x] pgTAP database contract tests.

## 20. Remaining external gates

The engineering foundation does not satisfy these Phase 0 gates by itself:

- confirm the launch wedge with real aspirants;
- test Tamil-first versus bilingual comprehension;
- archive and map the applicable official syllabus;
- produce and review the 30–50 question truth sample;
- recruit a pilot cohort/channel;
- measure review minutes and unit economics;
- complete the seven-day prototype pilot.

Until those pass, the correct status is **engineering foundation implemented; scored public launch blocked**.

## 21. Phase 2 entry gate

Phase 2 may build the smallest learner loop when:

- the migrations apply cleanly in the target Supabase project;
- all database and repository checks pass;
- at least 30 varied questions are publishable through the controlled function;
- the official syllabus top levels are mapped;
- learner-safe retrieval is tested under anon/authenticated roles;
- correction and suppression are exercised once in staging;
- the identity merge contract from Phase 0 is approved;
- the selected wedge and explanation mode have supporting evidence.

Phase 2 will then add sessions, attempts, idempotent offline sync, diagnostic practice, and deterministic mastery evidence without weakening the truth layer.
