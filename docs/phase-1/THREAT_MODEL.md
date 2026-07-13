# Phase 1 threat model

| Threat | Preventive control | Detection / recovery |
|---|---|---|
| Experimental question enters scored bank | Publication validator rejects `experimental` | CI/static guard and pgTAP rejection test |
| Correct answer leaks before submission | Answer-free learner view; no learner base-table grants | CI scans learner view; pgTAP checks missing column |
| Published question is edited in place | Version and child immutability triggers | Create successor; correction impact record |
| Child row is moved away from a locked version | Trigger checks both old and new version IDs | pgTAP reassignment rejection test |
| Nested JSON hides answer keys | Recursive forbidden-key validator | pgTAP nested-answer test |
| Learner forges report severity/resolution | Column-level insert grant plus normalization trigger | Staff triage and report audit fields |
| Wrong source is silently replaced | Referenced sources become immutable | Create new source and successor version |
| Current pointer targets a draft | Same-question published-pointer trigger | pgTAP pointer rejection test |
| Stable question changes exam identity | Identity trigger after first version exists | Create a new stable question when concept identity changes |
| Model output becomes canonical truth | Generation metadata is auxiliary; review and source rules remain mandatory | Validator and reviewer records |
| Defective published content remains visible | Suppression function clears current pointer and marks disputed | Publication event and correction workflow |
| API/client duplicates trust logic incorrectly | Database workflow is the publication authority | API contract review and CI checks |

Residual risks include operational reviewer quality, incorrect authoritative sources, semantic answer leakage not represented by forbidden JSON keys, and unexecuted staging database tests. These remain explicit gates rather than hidden assumptions.
