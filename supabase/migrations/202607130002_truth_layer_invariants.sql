-- Parikshai Phase 1: invariants and immutability.

create or replace function content.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger exams_set_updated_at
before update on content.exams
for each row execute function content.set_updated_at();

create trigger question_versions_set_updated_at
before update on content.question_versions
for each row execute function content.set_updated_at();

create trigger question_reports_set_updated_at
before update on content.question_reports
for each row execute function content.set_updated_at();

create trigger corrections_set_updated_at
before update on content.corrections
for each row execute function content.set_updated_at();

create or replace function content.is_staff(required_roles content.staff_role[] default array['editor', 'reviewer', 'admin']::content.staff_role[])
returns boolean
language sql
stable
security definer
set search_path = content, public, auth
as $$
  select
    session_user = 'postgres'
    or exists (
      select 1
      from content.staff_users su
      where su.user_id = auth.uid()
        and su.role = any(required_roles)
    );
$$;

create or replace function content.my_staff_role()
returns content.staff_role
language sql
stable
security definer
set search_path = content, public
as $$
  select su.role from content.staff_users su where su.user_id = auth.uid();
$$;

create or replace function content.can_read_version(p_version_id uuid)
returns boolean
language sql
stable
security definer
set search_path = content, public
as $$
  select exists (
    select 1
    from content.question_versions qv
    where qv.id = p_version_id
      and qv.status = 'published'
      and (qv.published_at is null or qv.published_at <= now())
      and (qv.valid_from is null or qv.valid_from <= now())
      and (qv.valid_until is null or qv.valid_until > now())
      and (qv.expires_at is null or qv.expires_at > now())
  ) or content.is_staff();
$$;

create or replace function content.valid_status_transition(old_status content.content_status, new_status content.content_status)
returns boolean
language sql
immutable
as $$
  select old_status = new_status or case old_status
    when 'imported' then new_status in ('structurally_valid', 'archived')
    when 'structurally_valid' then new_status in ('answer_verified', 'imported', 'archived')
    when 'answer_verified' then new_status in ('explanation_verified', 'structurally_valid', 'archived')
    when 'explanation_verified' then new_status in ('language_reviewed', 'answer_verified', 'archived')
    when 'language_reviewed' then new_status in ('publishable', 'explanation_verified', 'archived')
    when 'publishable' then new_status in ('published', 'language_reviewed', 'archived')
    when 'published' then new_status in ('disputed', 'corrected', 'archived')
    when 'disputed' then new_status in ('published', 'corrected', 'archived')
    when 'corrected' then new_status in ('archived')
    when 'archived' then false
  end;
$$;

create or replace function content.enforce_question_status_transition()
returns trigger
language plpgsql
as $$
begin
  if not content.valid_status_transition(old.status, new.status) then
    raise exception 'Invalid question status transition: % -> %', old.status, new.status;
  end if;

  if new.status in ('published', 'disputed', 'corrected', 'archived')
     and new.status <> old.status
     and coalesce(current_setting('content.publish_context', true), '0') <> '1' then
    raise exception 'Direct terminal/public status transitions are prohibited; use the content workflow functions';
  end if;

  return new;
end;
$$;

create trigger question_versions_enforce_status
before update of status on content.question_versions
for each row execute function content.enforce_question_status_transition();

create or replace function content.prevent_locked_version_mutation()
returns trigger
language plpgsql
as $$
declare
  old_payload jsonb;
  new_payload jsonb;
begin
  if old.status in ('published', 'disputed', 'corrected', 'archived') then
    old_payload := to_jsonb(old) - array[
      'status', 'published_at', 'disputed_at', 'archived_at', 'updated_at'
    ];
    new_payload := to_jsonb(new) - array[
      'status', 'published_at', 'disputed_at', 'archived_at', 'updated_at'
    ];

    if old_payload is distinct from new_payload then
      raise exception 'Published or terminal question versions are immutable; create a successor version';
    end if;
  end if;

  return new;
end;
$$;

create trigger question_versions_prevent_locked_mutation
before update on content.question_versions
for each row execute function content.prevent_locked_version_mutation();

create or replace function content.prevent_locked_version_delete()
returns trigger
language plpgsql
as $$
begin
  if old.status in ('published', 'disputed', 'corrected', 'archived') then
    raise exception 'Published or terminal question versions cannot be deleted';
  end if;
  return old;
end;
$$;

create trigger question_versions_prevent_locked_delete
before delete on content.question_versions
for each row execute function content.prevent_locked_version_delete();

create or replace function content.prevent_append_only_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception '% is append-only', tg_table_name;
end;
$$;

create trigger content_reviews_append_only
before update or delete on content.content_reviews
for each row execute function content.prevent_append_only_mutation();

create trigger generation_runs_append_only
before update or delete on content.generation_runs
for each row execute function content.prevent_append_only_mutation();

create trigger validator_results_append_only
before update or delete on content.validator_results
for each row execute function content.prevent_append_only_mutation();

create trigger publication_events_append_only
before update or delete on content.publication_events
for each row execute function content.prevent_append_only_mutation();

create or replace function content.enforce_successor_version()
returns trigger
language plpgsql
as $$
declare
  prior content.question_versions%rowtype;
begin
  if new.supersedes_version_id is null then
    return new;
  end if;

  select * into prior
  from content.question_versions
  where id = new.supersedes_version_id;

  if not found then
    raise exception 'Superseded version does not exist';
  end if;

  if prior.question_id <> new.question_id then
    raise exception 'A successor must belong to the same stable question';
  end if;

  if new.version_number <= prior.version_number then
    raise exception 'A successor version number must be greater than the superseded version';
  end if;

  return new;
end;
$$;

create trigger question_versions_enforce_successor
before insert or update of supersedes_version_id, question_id, version_number on content.question_versions
for each row execute function content.enforce_successor_version();

create or replace function content.enforce_syllabus_parent()
returns trigger
language plpgsql
as $$
declare
  parent_node content.syllabus_nodes%rowtype;
begin
  if new.parent_id is null then
    if new.depth <> 0 then
      raise exception 'Root syllabus nodes must have depth 0';
    end if;
    return new;
  end if;

  select * into parent_node from content.syllabus_nodes where id = new.parent_id;
  if not found then
    raise exception 'Syllabus parent does not exist';
  end if;
  if parent_node.exam_version_id <> new.exam_version_id then
    raise exception 'Syllabus parent and child must belong to the same exam version';
  end if;
  if new.depth <> parent_node.depth + 1 then
    raise exception 'Syllabus child depth must equal parent depth + 1';
  end if;
  return new;
end;
$$;

create trigger syllabus_nodes_enforce_parent
before insert or update of parent_id, exam_version_id, depth on content.syllabus_nodes
for each row execute function content.enforce_syllabus_parent();

create or replace function content.enforce_question_initial_status()
returns trigger
language plpgsql
as $$
begin
  if new.status in ('published', 'disputed', 'corrected') then
    raise exception 'Question versions cannot be inserted directly into a terminal/public state';
  end if;
  return new;
end;
$$;

create trigger question_versions_enforce_initial_status
before insert on content.question_versions
for each row execute function content.enforce_question_initial_status();

create or replace function content.prevent_locked_child_mutation()
returns trigger
language plpgsql
as $$
declare
  old_version_status content.content_status;
  new_version_status content.content_status;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    select status into old_version_status
    from content.question_versions
    where id = old.question_version_id;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select status into new_version_status
    from content.question_versions
    where id = new.question_version_id;
  end if;

  if old_version_status in ('published', 'disputed', 'corrected', 'archived')
     or new_version_status in ('published', 'disputed', 'corrected', 'archived') then
    raise exception 'Child records of a published or terminal question version are immutable; create a successor version';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger question_options_prevent_locked_mutation
before insert or update or delete on content.question_options
for each row execute function content.prevent_locked_child_mutation();

create trigger question_assets_prevent_locked_mutation
before insert or update or delete on content.question_assets
for each row execute function content.prevent_locked_child_mutation();

create trigger question_mappings_prevent_locked_mutation
before insert or update or delete on content.question_syllabus_mappings
for each row execute function content.prevent_locked_child_mutation();

create trigger question_sources_prevent_locked_mutation
before insert or update or delete on content.question_sources
for each row execute function content.prevent_locked_child_mutation();

create trigger explanations_prevent_locked_mutation
before insert or update or delete on content.explanations
for each row execute function content.prevent_locked_child_mutation();

create or replace function content.prevent_referenced_passage_mutation()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1 from content.question_versions qv
    where qv.passage_id = old.id
      and qv.status in ('published', 'disputed', 'corrected', 'archived')
  ) then
    raise exception 'A passage referenced by published or terminal content is immutable';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger passages_prevent_referenced_mutation
before update or delete on content.passages
for each row execute function content.prevent_referenced_passage_mutation();

create or replace function content.prevent_referenced_source_mutation()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from content.question_sources qs
    join content.question_versions qv on qv.id = qs.question_version_id
    where qs.source_document_id = old.id
      and qv.status in ('published', 'disputed', 'corrected', 'archived')
  ) then
    raise exception 'A source linked to published or terminal content is immutable; create a new source record';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger source_documents_prevent_referenced_mutation
before update or delete on content.source_documents
for each row execute function content.prevent_referenced_source_mutation();

create or replace function content.prevent_referenced_syllabus_mutation()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from content.question_syllabus_mappings qsm
    join content.question_versions qv on qv.id = qsm.question_version_id
    where qsm.syllabus_node_id = old.id
      and qv.status in ('published', 'disputed', 'corrected', 'archived')
  ) then
    raise exception 'A syllabus node mapped to published or terminal content is immutable; create a new exam version';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger syllabus_nodes_prevent_referenced_mutation
before update or delete on content.syllabus_nodes
for each row execute function content.prevent_referenced_syllabus_mutation();

create or replace function content.enforce_current_published_pointer()
returns trigger
language plpgsql
as $$
begin
  if new.current_published_version_id is null then
    return new;
  end if;

  if not exists (
    select 1 from content.question_versions qv
    where qv.id = new.current_published_version_id
      and qv.question_id = new.id
      and qv.status = 'published'
  ) then
    raise exception 'Current published pointer must reference a published version of the same question';
  end if;

  return new;
end;
$$;

create trigger questions_enforce_current_pointer
before insert or update of current_published_version_id on content.questions
for each row execute function content.enforce_current_published_pointer();

create or replace function content.prevent_question_identity_mutation()
returns trigger
language plpgsql
as $$
begin
  if (old.stable_key is distinct from new.stable_key
      or old.exam_version_id is distinct from new.exam_version_id)
     and exists (select 1 from content.question_versions qv where qv.question_id = old.id) then
    raise exception 'Stable question identity and exam version cannot change after versions exist';
  end if;
  return new;
end;
$$;

create trigger questions_prevent_identity_mutation
before update of stable_key, exam_version_id on content.questions
for each row execute function content.prevent_question_identity_mutation();

create or replace function content.enforce_correction_lineage()
returns trigger
language plpgsql
as $$
begin
  if not exists (
    select 1
    from content.question_versions old_v
    join content.question_versions new_v on new_v.id = new.new_version_id
    where old_v.id = new.old_version_id
      and new_v.question_id = old_v.question_id
      and new_v.supersedes_version_id = old_v.id
      and new_v.version_number > old_v.version_number
  ) then
    raise exception 'Correction must link a valid successor version of the same question';
  end if;
  return new;
end;
$$;

create trigger corrections_enforce_lineage
before insert or update of old_version_id, new_version_id on content.corrections
for each row execute function content.enforce_correction_lineage();
