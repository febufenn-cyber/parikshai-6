-- Parikshai Phase 2: learner identity, sessions, attempts, and recovery state.

create schema if not exists learning;
comment on schema learning is 'Phase 2 learner identity and reliable practice loop.';

create type learning.anonymous_identity_state as enum ('active', 'attached', 'revoked');
create type learning.identity_migration_status as enum ('completed', 'conflict', 'rejected');
create type learning.session_kind as enum ('diagnostic', 'daily', 'topic');
create type learning.session_status as enum ('created', 'active', 'completed', 'abandoned');
create type learning.session_question_status as enum ('pending', 'answered', 'skipped');
create type learning.scoring_status as enum ('scored', 'unscored', 'invalidated');

create table learning.learner_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (display_name is null or char_length(display_name) <= 120),
  preferred_language text not null default 'ta' check (preferred_language ~ '^[a-z]{2,3}(-[A-Z]{2})?$'),
  exam_id text references content.exams(id) on delete set null,
  onboarding jsonb not null default '{}'::jsonb check (jsonb_typeof(onboarding) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table learning.anonymous_identities (
  id uuid primary key default gen_random_uuid(),
  secret_hash bytea not null,
  state learning.anonymous_identity_state not null default 'active',
  attached_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  attached_at timestamptz,
  revoked_at timestamptz,
  check ((state = 'active' and attached_user_id is null and attached_at is null and revoked_at is null)
    or (state = 'attached' and attached_user_id is not null and attached_at is not null and revoked_at is null)
    or (state = 'revoked' and revoked_at is not null))
);

create table learning.identity_migrations (
  id uuid primary key default gen_random_uuid(),
  anonymous_id uuid not null references learning.anonymous_identities(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null unique,
  status learning.identity_migration_status not null,
  conflict_policy text not null default 'preserve_remote' check (conflict_policy in ('preserve_remote', 'merge_non_destructive')),
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
  migrated_at timestamptz not null default now(),
  unique (anonymous_id, user_id)
);

create table learning.practice_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users(id) on delete cascade,
  owner_anonymous_id uuid references learning.anonymous_identities(id) on delete cascade,
  kind learning.session_kind not null,
  status learning.session_status not null default 'created',
  exam_id text not null references content.exams(id) on delete restrict,
  topic_node_id text references content.syllabus_nodes(id) on delete restrict,
  language text not null check (language ~ '^[a-z]{2,3}(-[A-Z]{2})?$'),
  requested_question_count integer not null check (requested_question_count between 1 and 50),
  client_session_key uuid not null unique,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  abandoned_at timestamptz,
  last_activity_at timestamptz not null default now(),
  check (num_nonnulls(owner_user_id, owner_anonymous_id) = 1),
  check ((kind = 'topic' and topic_node_id is not null) or kind <> 'topic'),
  check ((status = 'completed' and completed_at is not null) or status <> 'completed'),
  check ((status = 'abandoned' and abandoned_at is not null) or status <> 'abandoned')
);

create index practice_sessions_user_active_idx
  on learning.practice_sessions(owner_user_id, last_activity_at desc)
  where owner_user_id is not null and status in ('created', 'active');
create index practice_sessions_anonymous_active_idx
  on learning.practice_sessions(owner_anonymous_id, last_activity_at desc)
  where owner_anonymous_id is not null and status in ('created', 'active');

create table learning.session_questions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references learning.practice_sessions(id) on delete cascade,
  ordinal integer not null check (ordinal >= 1),
  question_version_id uuid not null references content.question_versions(id) on delete restrict,
  public_payload_snapshot jsonb not null check (jsonb_typeof(public_payload_snapshot) = 'object'),
  status learning.session_question_status not null default 'pending',
  inserted_at timestamptz not null default now(),
  answered_at timestamptz,
  unique (session_id, ordinal),
  unique (session_id, question_version_id),
  check ((status = 'answered' and answered_at is not null) or status <> 'answered')
);

create table learning.answer_submissions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references learning.practice_sessions(id) on delete restrict,
  session_question_id uuid not null references learning.session_questions(id) on delete restrict,
  owner_user_id uuid references auth.users(id) on delete cascade,
  owner_anonymous_id uuid references learning.anonymous_identities(id) on delete cascade,
  idempotency_key uuid not null unique,
  selected_option_ids text[] not null default '{}',
  response_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(response_payload) = 'object'),
  elapsed_ms integer check (elapsed_ms is null or elapsed_ms between 0 and 86400000),
  client_submitted_at timestamptz,
  server_received_at timestamptz not null default now(),
  is_final boolean not null default true,
  request_hash bytea not null,
  check (num_nonnulls(owner_user_id, owner_anonymous_id) = 1),
  unique (session_question_id, is_final)
);

create table learning.answer_results (
  submission_id uuid primary key references learning.answer_submissions(id) on delete restrict,
  question_version_id uuid not null references content.question_versions(id) on delete restrict,
  scoring_status learning.scoring_status not null default 'scored',
  is_correct boolean,
  score numeric(6,3),
  correct_option_ids text[] not null default '{}',
  answer_snapshot jsonb not null check (jsonb_typeof(answer_snapshot) = 'object'),
  explanation_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(explanation_snapshot) = 'object'),
  provenance_snapshot jsonb not null default '[]'::jsonb check (jsonb_typeof(provenance_snapshot) = 'array'),
  scored_at timestamptz not null default now(),
  invalidated_at timestamptz,
  invalidation_reason text,
  check ((scoring_status = 'invalidated' and invalidated_at is not null) or scoring_status <> 'invalidated')
);

create table learning.bookmarks (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users(id) on delete cascade,
  owner_anonymous_id uuid references learning.anonymous_identities(id) on delete cascade,
  question_version_id uuid not null references content.question_versions(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (num_nonnulls(owner_user_id, owner_anonymous_id) = 1)
);
create unique index bookmarks_user_question_idx on learning.bookmarks(owner_user_id, question_version_id) where owner_user_id is not null;
create unique index bookmarks_anonymous_question_idx on learning.bookmarks(owner_anonymous_id, question_version_id) where owner_anonymous_id is not null;

create table learning.session_recovery (
  session_id uuid primary key references learning.practice_sessions(id) on delete cascade,
  cursor_ordinal integer not null default 1 check (cursor_ordinal >= 1),
  state_version bigint not null default 1 check (state_version >= 1),
  client_state jsonb not null default '{}'::jsonb check (jsonb_typeof(client_state) = 'object'),
  updated_at timestamptz not null default now()
);

create table learning.idempotency_receipts (
  idempotency_key uuid primary key,
  owner_user_id uuid references auth.users(id) on delete cascade,
  owner_anonymous_id uuid references learning.anonymous_identities(id) on delete cascade,
  operation text not null,
  request_hash bytea not null,
  response_payload jsonb not null check (jsonb_typeof(response_payload) in ('object', 'array')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  check (num_nonnulls(owner_user_id, owner_anonymous_id) = 1)
);

create table learning.evidence_events (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users(id) on delete cascade,
  owner_anonymous_id uuid references learning.anonymous_identities(id) on delete cascade,
  session_id uuid not null references learning.practice_sessions(id) on delete restrict,
  session_question_id uuid not null references learning.session_questions(id) on delete restrict,
  submission_id uuid not null unique references learning.answer_submissions(id) on delete restrict,
  question_version_id uuid not null references content.question_versions(id) on delete restrict,
  syllabus_node_id text references content.syllabus_nodes(id) on delete restrict,
  is_correct boolean,
  score numeric(6,3),
  elapsed_ms integer,
  event_kind text not null default 'answer_result' check (event_kind in ('answer_result', 'result_invalidated', 'correction_replay')),
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  check (num_nonnulls(owner_user_id, owner_anonymous_id) = 1)
);

create index evidence_events_user_time_idx on learning.evidence_events(owner_user_id, occurred_at desc) where owner_user_id is not null;
create index evidence_events_anonymous_time_idx on learning.evidence_events(owner_anonymous_id, occurred_at desc) where owner_anonymous_id is not null;
