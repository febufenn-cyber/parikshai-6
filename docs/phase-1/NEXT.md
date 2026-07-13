# Next implementation move

After Phase 1 is merged and staging database tests pass, Phase 2 should implement the smallest complete learner loop:

1. anonymous onboarding identity;
2. authenticated progress attachment;
3. diagnostic and daily practice sessions;
4. immutable attempt records referencing exact question versions;
5. idempotent offline submission sync;
6. answer reveal only after accepted submission;
7. mistake review and report-question flow;
8. progress restoration after reinstall;
9. deterministic evidence records, without yet claiming a sophisticated mastery model.

Phase 2 must consume the truth-layer views and workflow functions rather than bypassing them.
