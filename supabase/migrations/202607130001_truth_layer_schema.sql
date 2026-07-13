-- Parikshai Phase 1: canonical content truth layer.
-- This migration assumes a Supabase project with auth.users and the anon/authenticated roles.

create extension if not exists pgcrypto;
create schema if not exists content;

comment on schema content is 'Versioned, reviewed, and auditable exam content.';

create type content.content_class as enum (
  'official',
  'curated',
  'ai_assisted',
  'experimental'
);

create type content.content_status as enum (
  'imported',
  'structurally_valid',
  'answer_verified',
  'explanation_verified',
  'language_reviewed',
  'publishable',
  'published',
  'disputed',
  'corrected',
  'archived'
);

create type content.question_type as enum (
  'direct_mcq',
  'multi_statement',
  'assertion_reason',
  'match',
  'passage_linked',
  'table_data',
  'chronology',
  'numerical',
  'image_diagram',
  'multi_select'
);

create type content.source_kind as enum (
  'official_question_paper',
  'official_final_key',
  'official_notification',
  'government_publication',
  'prescribed_text',
  'curated_reference',
  'editorial_original',
  'other'
);

create type content.source_claim_role as enum (
  'question_text',
  'answer',
  'explanation',
  'translation',
  'syllabus_mapping',
  'multiple'
);

create type content.review_kind as enum (
  'structure',
  'answer',
  'explanation',
  'language',
  'rendering',
  'source',
  'final_publication',
  'dispute'
);

create type content.review_decision as enum (
  'approved',
  'changes_requested',
  'rejected',
  'needs_evidence'
);

create type content.validator_severity as enum (
  'info',
  'warning',
  'high',
  'critical'
);

create type content.staff_role as enum (
  'editor',
  'reviewer',
  'admin'
);

create type content.report_status as enum (
  'open',
  'triaged',
  'suppressed',
  'resolved',
  'rejected'
);

create type content.correction_impact_status as enum (
  'pending',
  'no_learner_impact',
  'attempts_identified',
  'recalculated',
  'learners_notified'
);

create table content.staff_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role content.staff_role not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table content.exams (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9_-]+$'),
  name jsonb not null check (jsonb_typeof(name) = 'object' and jsonb_object_length(name) > 0),
  jurisdiction text not null,
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table content.exam_versions (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9_.-]+$'),
  exam_id text not null references content.exams(id) on delete restrict,
  label text not null,
  valid_from date,
  valid_until date,
  official_source_uri text,
  source_sha256 text check (source_sha256 is null or source_sha256 ~ '^[0-9a-f]{64}$'),
  active boolean not null default false,
  created_at timestamptz not null default now(),
  check (valid_until is null or valid_from is null or valid_until >= valid_from)
);

create table content.syllabus_nodes (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9_.:-]+$'),
  exam_version_id text not null references content.exam_versions(id) on delete restrict,
  parent_id text references content.syllabus_nodes(id) on delete restrict,
  node_kind text not null check (node_kind in ('paper', 'subject', 'unit', 'topic', 'micro_skill', 'current_affairs')),
  code text,
  title jsonb not null check (jsonb_typeof(title) = 'object' and jsonb_object_length(title) > 0),
  path text not null,
  depth integer not null check (depth >= 0),
  sort_order integer not null default 0,
  relevance_from date,
  relevance_until date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (exam_version_id, path),
  check (relevance_until is null or relevance_from is null or relevance_until >= relevance_from)
);

create table content.source_documents (
  id uuid primary key default gen_random_uuid(),
  kind content.source_kind not null,
  title text not null,
  issuer text,
  source_uri text,
  storage_path text,
  sha256 text check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$'),
  published_on date,
  effective_from date,
  effective_until date,
  is_final_key boolean not null default false,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  check (source_uri is not null or storage_path is not null),
  check (effective_until is null or effective_from is null or effective_until >= effective_from)
);

create table content.passages (
  id uuid primary key default gen_random_uuid(),
  stable_key text not null unique check (stable_key ~ '^passage_[a-z0-9_]+$'),
  original_language text not null,
  content jsonb not null check (jsonb_typeof(content) = 'object' and jsonb_object_length(content) > 0),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table content.questions (
  id uuid primary key default gen_random_uuid(),
  stable_key text not null unique check (stable_key ~ '^q_[a-z0-9_]+$'),
  exam_version_id text not null references content.exam_versions(id) on delete restrict,
  current_published_version_id uuid,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  retired_at timestamptz
);

create table content.question_versions (
  id uuid primary key default gen_random_uuid(),
  version_key text not null unique check (version_key ~ '^qv_[a-z0-9_]+$'),
  question_id uuid not null references content.questions(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  supersedes_version_id uuid references content.question_versions(id) on delete restrict,
  content_class content.content_class not null,
  status content.content_status not null default 'imported',
  question_type content.question_type not null,
  original_language text not null,
  passage_id uuid references content.passages(id) on delete restrict,
  prompt jsonb not null check (jsonb_typeof(prompt) = 'object' and jsonb_object_length(prompt) > 0),
  shared_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(shared_payload) = 'object'),
  answer_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(answer_payload) = 'object'),
  difficulty numeric(4,3) check (difficulty is null or (difficulty >= 0 and difficulty <= 1)),
  valid_from timestamptz,
  valid_until timestamptz,
  expires_at timestamptz,
  answer_verified_at timestamptz,
  explanation_verified_at timestamptz,
  language_reviewed_at timestamptz,
  rendering_validated_at timestamptz,
  published_at timestamptz,
  disputed_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  unique (question_id, version_number),
  check (valid_until is null or valid_from is null or valid_until >= valid_from),
  check (expires_at is null or published_at is null or expires_at > published_at),
  check (supersedes_version_id is null or supersedes_version_id <> id)
);

alter table content.questions
  add constraint questions_current_published_version_fk
  foreign key (current_published_version_id)
  references content.question_versions(id)
  on delete restrict;

create table content.question_options (
  id uuid primary key default gen_random_uuid(),
  question_version_id uuid not null references content.question_versions(id) on delete cascade,
  option_key text not null check (option_key ~ '^[a-zA-Z0-9_-]+$'),
  position integer not null check (position >= 0),
  text jsonb not null check (jsonb_typeof(text) = 'object' and jsonb_object_length(text) > 0),
  unique (question_version_id, option_key),
  unique (question_version_id, position)
);

create table content.question_assets (
  id uuid primary key default gen_random_uuid(),
  question_version_id uuid not null references content.question_versions(id) on delete cascade,
  asset_kind text not null check (asset_kind in ('image', 'diagram', 'table', 'audio', 'document')),
  storage_path text not null,
  sha256 text check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$'),
  alt_text jsonb not null default '{}'::jsonb check (jsonb_typeof(alt_text) = 'object'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create table content.question_syllabus_mappings (
  question_version_id uuid not null references content.question_versions(id) on delete cascade,
  syllabus_node_id text not null references content.syllabus_nodes(id) on delete restrict,
  is_primary boolean not null default false,
  confidence numeric(4,3) not null default 1 check (confidence >= 0 and confidence <= 1),
  cognitive_tag text check (cognitive_tag is null or cognitive_tag in (
    'recall', 'comprehension', 'application', 'analysis', 'comparison',
    'sequencing', 'calculation', 'interpretation'
  )),
  mapped_by uuid references auth.users(id),
  mapped_at timestamptz not null default now(),
  primary key (question_version_id, syllabus_node_id)
);

create unique index question_one_primary_syllabus_idx
  on content.question_syllabus_mappings (question_version_id)
  where is_primary;

create table content.question_sources (
  question_version_id uuid not null references content.question_versions(id) on delete cascade,
  source_document_id uuid not null references content.source_documents(id) on delete restrict,
  claim_role content.source_claim_role not null,
  source_locator text,
  notes text,
  linked_at timestamptz not null default now(),
  linked_by uuid references auth.users(id),
  primary key (question_version_id, source_document_id, claim_role)
);

create table content.explanations (
  id uuid primary key default gen_random_uuid(),
  question_version_id uuid not null references content.question_versions(id) on delete cascade,
  language text not null,
  explanation_level text not null default 'exam_focused' check (explanation_level in ('simple', 'exam_focused', 'detailed')),
  body jsonb not null check (jsonb_typeof(body) = 'object' and jsonb_object_length(body) > 0),
  glossary_version text,
  verified boolean not null default false,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (question_version_id, language, explanation_level)
);

create table content.content_reviews (
  id uuid primary key default gen_random_uuid(),
  question_version_id uuid not null references content.question_versions(id) on delete cascade,
  kind content.review_kind not null,
  decision content.review_decision not null,
  checklist jsonb not null default '{}'::jsonb check (jsonb_typeof(checklist) = 'object'),
  notes text,
  reviewer_id uuid not null references auth.users(id),
  reviewed_at timestamptz not null default now()
);

create table content.generation_runs (
  id uuid primary key default gen_random_uuid(),
  question_version_id uuid not null unique references content.question_versions(id) on delete cascade,
  provider text not null,
  model text not null,
  model_version text,
  prompt_version text not null,
  source_context_ids jsonb not null default '[]'::jsonb check (jsonb_typeof(source_context_ids) = 'array'),
  input_hash text,
  generated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object')
);

create table content.validator_results (
  id uuid primary key default gen_random_uuid(),
  question_version_id uuid not null references content.question_versions(id) on delete cascade,
  validator_code text not null,
  validator_version text,
  severity content.validator_severity not null,
  passed boolean not null,
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
  executed_at timestamptz not null default now()
);

create table content.question_reports (
  id uuid primary key default gen_random_uuid(),
  question_version_id uuid not null references content.question_versions(id) on delete restrict,
  reporter_id uuid references auth.users(id) on delete set null,
  reason_code text not null,
  description text,
  status content.report_status not null default 'open',
  severity content.validator_severity not null default 'warning',
  triaged_by uuid references auth.users(id),
  triaged_at timestamptz,
  resolution_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table content.corrections (
  id uuid primary key default gen_random_uuid(),
  old_version_id uuid not null references content.question_versions(id) on delete restrict,
  new_version_id uuid not null references content.question_versions(id) on delete restrict,
  reason text not null,
  learner_materiality text not null check (learner_materiality in ('none', 'minor', 'score_affecting', 'concept_affecting')),
  impact_status content.correction_impact_status not null default 'pending',
  affected_attempt_count bigint,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (old_version_id, new_version_id),
  check (old_version_id <> new_version_id)
);

create table content.publication_events (
  id bigint generated always as identity primary key,
  question_version_id uuid not null references content.question_versions(id) on delete restrict,
  event_type text not null check (event_type in ('published', 'republished', 'disputed', 'corrected', 'archived')),
  actor_id uuid references auth.users(id),
  reason text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index question_versions_question_idx on content.question_versions(question_id, version_number desc);
create index question_versions_status_idx on content.question_versions(status, published_at);
create index question_versions_expiry_idx on content.question_versions(expires_at) where expires_at is not null;
create index syllabus_nodes_parent_idx on content.syllabus_nodes(parent_id, sort_order);
create index syllabus_nodes_exam_idx on content.syllabus_nodes(exam_version_id, path);
create index question_mappings_node_idx on content.question_syllabus_mappings(syllabus_node_id, is_primary);
create index question_sources_document_idx on content.question_sources(source_document_id);
create index explanations_version_idx on content.explanations(question_version_id, language, verified);
create index reviews_version_idx on content.content_reviews(question_version_id, kind, reviewed_at desc);
create index validators_version_idx on content.validator_results(question_version_id, passed, severity);
create index reports_open_idx on content.question_reports(status, severity, created_at) where status in ('open', 'triaged', 'suppressed');
create index corrections_impact_idx on content.corrections(impact_status, created_at);
