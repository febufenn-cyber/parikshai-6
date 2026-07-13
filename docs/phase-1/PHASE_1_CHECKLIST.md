# Phase 1 completion checklist

## Engineering foundation

- [x] Stable question identity is separated from immutable versions.
- [x] Official, curated, AI-assisted, and experimental classes are represented.
- [x] Publication uses one database-controlled workflow.
- [x] Experimental content is prohibited from publication.
- [x] Sources and one primary syllabus mapping are required.
- [x] Answers, explanations, language, and rendering have separate verification evidence.
- [x] Published versions and child payloads are immutable.
- [x] Corrections require successor lineage.
- [x] Suppression removes defective content without deleting history.
- [x] Learner-safe views omit canonical answers and explanation bodies.
- [x] Learner question reports cannot forge staff fields.
- [x] Fixture and SQL-contract validation run in CI.
- [x] A 34-assertion pgTAP suite is present.

## Staging validation still required

- [ ] Initialize the Supabase local project configuration.
- [ ] Run all migrations with `supabase db reset`.
- [ ] Run `supabase test db` successfully.
- [ ] Verify anon/authenticated retrieval against learner-safe views.
- [ ] Exercise publish, suppress, successor correction, and archive once.
- [ ] Confirm the target Supabase/Postgres version supports every migration option.

## External/product gates still required

- [ ] Confirm TNPSC Group IV remains the correct first wedge.
- [ ] Test Tamil-first versus bilingual comprehension.
- [ ] Import the applicable official syllabus version.
- [ ] Produce 30–50 fully reviewed truth-sample questions.
- [ ] Measure human review time and unit economics.
- [ ] Complete the seven-day prototype pilot.

Phase 2 may be prototyped, but scored public launch remains blocked until the applicable staging and external gates pass.
