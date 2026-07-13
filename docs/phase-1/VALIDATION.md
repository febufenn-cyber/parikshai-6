# Phase 1 validation record

Date: 2026-07-13

## Executed

- `npm test`
  - validated the existing Tamil-English experimental fixture;
  - validated four ordered SQL migrations;
  - confirmed balanced PL/pgSQL `$$` delimiters;
  - confirmed required publication, immutability, answer-leak, and report-write guards;
  - confirmed the learner view omits canonical answers and explanation bodies;
  - confirmed the pgTAP plan matches 34 assertions.
- A deliberately invalid fixture was used during development to confirm the fixture validator rejects:
  - a correct option that does not exist;
  - experimental content in a scored/publication state;
  - unverified published content.
- `main...agent/phase-1-truth-layer` was inspected for unexpected files before PR creation.

## Authored but not executed in this environment

`supabase/tests/phase_1_truth_layer.sql` contains 34 pgTAP assertions. The current execution environment did not have PostgreSQL or the Supabase CLI installed, so the migration reset and pgTAP suite were not run here.

Required staging commands:

```bash
supabase init       # only when config.toml is absent
supabase start
supabase db reset
supabase test db
```

The Phase 2 entry gate remains blocked until these database tests pass against the target Supabase/Postgres version and suppression/correction are exercised once in staging.
