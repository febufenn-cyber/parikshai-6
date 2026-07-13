# Phase 1 decision log

Append decisions; do not rewrite history.

| Date | Decision | Status | Reason / revisit trigger |
|---|---|---|---|
| 2026-07-13 | Separate stable question identity from immutable question versions | Locked | Required for attempt replay and corrections; revisit only during a full data-platform migration |
| 2026-07-13 | Permit publication only through a database workflow function | Locked | Prevents application routes from drifting from trust rules |
| 2026-07-13 | Experimental content cannot be published or affect scored mastery | Locked | Trust boundary; never relax without equivalent quarantine |
| 2026-07-13 | Published versions and all learner-visible child payloads are immutable | Locked | Corrections create successor versions |
| 2026-07-13 | Learner clients receive answer-free security-barrier views, not canonical base-table access | Locked | RLS is row-level and cannot safely conceal answer columns by itself |
| 2026-07-13 | Answers and explanation bodies are returned by the API only after submission is recorded | Locked for Phase 2 | Revisit only if a different anti-cheating/product contract is explicitly approved |
| 2026-07-13 | Editorial CRUD is backend/service-role mediated; reviewer actions still require an authenticated staff identity | Locked for Phase 1 | A future editor app may add narrowly scoped RPCs |
| 2026-07-13 | TNPSC Group IV remains provisional despite engineering implementation | Provisional | Requires interviews, language comprehension test, truth sample, pilot, and economics evidence |
| 2026-07-13 | Phase 1 is “engineering foundation implemented,” not “public launch ready” | Locked until external gates pass | Prevents code completion from masquerading as product validation |
