# Supabase truth-layer setup

## Apply locally

Install the Supabase CLI. If this checkout does not yet contain `supabase/config.toml`, initialize it once before starting the local stack:

```bash
supabase init
supabase start
supabase db reset
supabase test db
```

The migrations are the first canonical content migrations. Do not edit an applied migration in an environment that contains real data; add a successor migration instead.

## Bootstrap the first staff administrator

Use a trusted SQL session after the user has signed in at least once:

```sql
insert into content.staff_users(user_id, role)
values ('<auth.users.id>', 'admin');
```

Never expose the Supabase service-role key to learner clients.

## Publish content

Editors advance review states and attach sources, mappings, options, explanations, and validator outcomes. A reviewer or administrator publishes only through:

```sql
select content.publish_question_version('<question-version-uuid>');
```

Direct terminal/public status changes are rejected.

## Suppress a defective question

```sql
select content.suppress_question_version(
  '<question-version-uuid>',
  'Confirmed answer-key or rendering defect'
);
```

Suppression preserves the historical version and appends an audit event.

## Validate before publishing

```sql
select *
from content.validate_question_version('<question-version-uuid>')
order by rule_code;
```

Every returned rule must pass.

## Correction rule

Never edit a published version or its options, mappings, sources, explanations, passage, or referenced source records. Create a successor version, set `supersedes_version_id`, review it, publish it, and add a `content.corrections` record.

## Archive a version

```sql
select content.archive_question_version('<question-version-uuid>', 'Superseded or withdrawn content');
```

## Learner answer boundary

Learner clients query only `content.api_exams`, `content.api_syllabus_nodes`, and `content.api_published_questions`. The published-question view intentionally omits `answer_payload` and explanation bodies. The Hono/API layer returns answers and explanations only after it records a submission in Phase 2.
