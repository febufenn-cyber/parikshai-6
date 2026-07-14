-- Parikshai Phase 2: backend-only access and immutable evidence boundaries.

create or replace function learning.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end;
$$;
create trigger learner_profiles_touch before update on learning.learner_profiles
for each row execute function learning.touch_updated_at();

create or replace function learning.reject_mutation()
returns trigger language plpgsql as $$
begin raise exception 'Append-only learner history cannot be updated or deleted'; end;
$$;

create or replace function learning.allow_owner_reassignment_only()
returns trigger language plpgsql as $$
begin
  if tg_op <> 'UPDATE' or coalesce(current_setting('learning.identity_migration_context',true),'0') <> '1' then
    raise exception 'Append-only learner history cannot be updated or deleted';
  end if;
  if (to_jsonb(old)-array['owner_user_id','owner_anonymous_id'])
     is distinct from (to_jsonb(new)-array['owner_user_id','owner_anonymous_id']) then
    raise exception 'Identity migration may only reassign owner fields';
  end if;
  if old.owner_anonymous_id is null or new.owner_user_id is null or new.owner_anonymous_id is not null then
    raise exception 'Identity migration owner transition is invalid';
  end if;
  return new;
end;
$$;

create trigger session_questions_no_update
before update of session_id, ordinal, question_version_id, public_payload_snapshot on learning.session_questions
for each row execute function learning.reject_mutation();
create trigger session_questions_no_delete before delete on learning.session_questions
for each row execute function learning.reject_mutation();
create trigger submissions_owner_reassignment before update on learning.answer_submissions
for each row execute function learning.allow_owner_reassignment_only();
create trigger submissions_no_delete before delete on learning.answer_submissions
for each row execute function learning.reject_mutation();
create trigger results_no_update before update or delete on learning.answer_results
for each row execute function learning.reject_mutation();
create trigger evidence_owner_reassignment before update on learning.evidence_events
for each row execute function learning.allow_owner_reassignment_only();
create trigger evidence_no_delete before delete on learning.evidence_events
for each row execute function learning.reject_mutation();
create trigger receipts_owner_reassignment before update on learning.idempotency_receipts
for each row execute function learning.allow_owner_reassignment_only();
create trigger receipts_no_delete before delete on learning.idempotency_receipts
for each row execute function learning.reject_mutation();
create trigger migrations_no_update before update or delete on learning.identity_migrations
for each row execute function learning.reject_mutation();

create or replace function learning.validate_public_snapshot()
returns trigger language plpgsql as $$
begin
  if content.jsonb_contains_key_recursive(new.public_payload_snapshot,
    array['answer','answers','answer_key','correct','correct_answer','correct_option_ids','rationale','explanation','explanation_body']) then
    raise exception 'Session question snapshot contains forbidden answer-bearing keys';
  end if;
  return new;
end;
$$;
create trigger session_question_answer_boundary
before insert on learning.session_questions
for each row execute function learning.validate_public_snapshot();

create or replace function content.normalize_question_report_insert()
returns trigger
language plpgsql
security definer
set search_path = content, public
as $$
begin
  if coalesce(current_setting('learning.report_context', true), '0') = '1' then
    new.status := 'open';
    new.severity := 'warning';
    new.triaged_by := null;
    new.triaged_at := null;
    new.resolution_notes := null;
  elsif not content.is_staff() then
    new.reporter_id := auth.uid();
    new.status := 'open';
    new.severity := 'warning';
    new.triaged_by := null;
    new.triaged_at := null;
    new.resolution_notes := null;
  end if;
  return new;
end;
$$;

alter table learning.learner_profiles enable row level security;
alter table learning.anonymous_identities enable row level security;
alter table learning.identity_migrations enable row level security;
alter table learning.practice_sessions enable row level security;
alter table learning.session_questions enable row level security;
alter table learning.answer_submissions enable row level security;
alter table learning.answer_results enable row level security;
alter table learning.bookmarks enable row level security;
alter table learning.session_recovery enable row level security;
alter table learning.idempotency_receipts enable row level security;
alter table learning.evidence_events enable row level security;

revoke all on schema learning from public, anon, authenticated;
revoke all on all tables in schema learning from public, anon, authenticated;
revoke all on all functions in schema learning from public, anon, authenticated;

grant usage on schema learning to service_role;
grant all on all tables in schema learning to service_role;
grant execute on all functions in schema learning to service_role;

comment on function learning.submit_answer is 'Atomic, idempotent scoring boundary. Returns answer material only after a submission is stored.';
comment on function learning.get_session_question is 'Pre-submission question delivery; rejects nested answer-bearing keys.';
comment on table learning.evidence_events is 'Append-only raw learning evidence. Phase 3 may derive mastery but must not rewrite these events.';
