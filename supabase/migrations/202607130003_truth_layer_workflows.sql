-- Parikshai Phase 1: publication, suppression, and archive workflows.

create or replace function content.jsonb_contains_key_recursive(p_payload jsonb, p_keys text[])
returns boolean
language plpgsql
immutable
as $$
declare
  item record;
begin
  if p_payload is null then
    return false;
  end if;

  if jsonb_typeof(p_payload) = 'object' then
    for item in select key, value from jsonb_each(p_payload) loop
      if item.key = any(p_keys)
         or content.jsonb_contains_key_recursive(item.value, p_keys) then
        return true;
      end if;
    end loop;
  elsif jsonb_typeof(p_payload) = 'array' then
    for item in select value from jsonb_array_elements(p_payload) loop
      if content.jsonb_contains_key_recursive(item.value, p_keys) then
        return true;
      end if;
    end loop;
  end if;

  return false;
end;
$$;

create or replace function content.validate_question_version(p_version_id uuid)
returns table(rule_code text, passed boolean, details text)
language plpgsql
stable
security definer
set search_path = content, public
as $$
declare
  v content.question_versions%rowtype;
  choice_based boolean;
begin
  if not content.is_staff() then
    raise exception 'Editorial role required';
  end if;

  select * into v
  from content.question_versions
  where id = p_version_id;

  if not found then
    raise exception 'Question version not found: %', p_version_id;
  end if;

  choice_based := v.question_type <> 'numerical';

  return query
  select 'status_ready', v.status in ('publishable', 'disputed'), 'Status must be publishable or disputed for republication'
  union all
  select 'not_experimental', v.content_class <> 'experimental', 'Experimental content cannot be published'
  union all
  select 'answer_verified', v.answer_verified_at is not null, 'Answer verification timestamp is required'
  union all
  select 'explanation_verified',
    v.explanation_verified_at is not null
      and exists (
        select 1 from content.explanations e
        where e.question_version_id = v.id and e.verified
      ),
    'At least one verified explanation and timestamp are required'
  union all
  select 'language_reviewed', v.language_reviewed_at is not null, 'Language review timestamp is required'
  union all
  select 'rendering_validated', v.rendering_validated_at is not null, 'Rendering validation timestamp is required'
  union all
  select 'source_present',
    exists (select 1 from content.question_sources qs where qs.question_version_id = v.id),
    'At least one provenance source is required'
  union all
  select 'answer_source_present',
    exists (
      select 1 from content.question_sources qs
      where qs.question_version_id = v.id and qs.claim_role in ('answer', 'multiple')
    ),
    'At least one source must support the answer'
  union all
  select 'official_source_matches_class',
    v.content_class <> 'official' or exists (
      select 1
      from content.question_sources qs
      join content.source_documents sd on sd.id = qs.source_document_id
      where qs.question_version_id = v.id
        and sd.kind in (
          'official_question_paper', 'official_final_key', 'official_notification',
          'government_publication', 'prescribed_text'
        )
    ),
    'Official content requires an authoritative source kind'
  union all
  select 'ai_assisted_generation_metadata',
    v.content_class <> 'ai_assisted' or exists (
      select 1 from content.generation_runs gr where gr.question_version_id = v.id
    ),
    'AI-assisted content requires generation metadata'
  union all
  select 'primary_syllabus_mapping',
    (select count(*) = 1 from content.question_syllabus_mappings qsm where qsm.question_version_id = v.id and qsm.is_primary),
    'Exactly one primary syllabus mapping is required'
  union all
  select 'syllabus_exam_version_match',
    exists (
      select 1
      from content.question_syllabus_mappings qsm
      join content.syllabus_nodes sn on sn.id = qsm.syllabus_node_id
      join content.questions q on q.id = v.question_id
      where qsm.question_version_id = v.id
        and qsm.is_primary
        and sn.exam_version_id = q.exam_version_id
    ),
    'Primary syllabus mapping must match the question exam version'
  union all
  select 'prompt_original_language',
    v.prompt ? v.original_language,
    'Prompt must include the original language key'
  union all
  select 'no_answer_leak_in_public_payload',
    not content.jsonb_contains_key_recursive(
      v.prompt,
      array['answer', 'correct_answer', 'correct_option_keys', 'answer_payload']
    )
      and not content.jsonb_contains_key_recursive(
        v.shared_payload,
        array['answer', 'correct_answer', 'correct_option_keys', 'answer_payload']
      ),
    'Prompt/shared payload must not contain answer-bearing keys at any depth'
  union all
  select 'choice_option_count',
    (not choice_based) or (select count(*) >= 2 from content.question_options qo where qo.question_version_id = v.id),
    'Choice-based questions require at least two options'
  union all
  select 'correct_answer_present',
    case
      when not choice_based then coalesce(jsonb_typeof(v.answer_payload), '') = 'object'
      else jsonb_typeof(v.answer_payload -> 'correct_option_keys') = 'array'
        and jsonb_array_length(v.answer_payload -> 'correct_option_keys') >= 1
    end,
    'Answer payload must declare at least one correct option key'
  union all
  select 'option_original_language',
    (not choice_based) or not exists (
      select 1 from content.question_options qo
      where qo.question_version_id = v.id
        and not (qo.text ? v.original_language)
    ),
    'Every option must include the original language key'
  union all
  select 'correct_keys_exist',
    (not choice_based) or not exists (
      select 1
      from jsonb_array_elements_text(coalesce(v.answer_payload -> 'correct_option_keys', '[]'::jsonb)) as key(value)
      where not exists (
        select 1 from content.question_options qo
        where qo.question_version_id = v.id and qo.option_key = key.value
      )
    ),
    'Every correct option key must exist in question_options'
  union all
  select 'correct_keys_unique',
    (not choice_based) or (
      select count(distinct key.value) = jsonb_array_length(coalesce(v.answer_payload -> 'correct_option_keys', '[]'::jsonb))
      from jsonb_array_elements_text(coalesce(v.answer_payload -> 'correct_option_keys', '[]'::jsonb)) as key(value)
    ),
    'Correct option keys must be unique'
  union all
  select 'single_answer_contract',
    v.question_type = 'multi_select'
      or not choice_based
      or jsonb_array_length(coalesce(v.answer_payload -> 'correct_option_keys', '[]'::jsonb)) = 1,
    'Only multi-select questions may declare multiple correct options'
  union all
  select 'no_blocking_validator_failure',
    not exists (
      select 1 from content.validator_results vr
      where vr.question_version_id = v.id
        and not vr.passed
        and vr.severity in ('high', 'critical')
    ),
    'High or critical validator failures must be resolved';
end;
$$;

create or replace function content.publish_question_version(p_version_id uuid)
returns uuid
language plpgsql
security definer
set search_path = content, public
as $$
declare
  v content.question_versions%rowtype;
  failures text;
  actor uuid := auth.uid();
begin
  if not content.is_staff(array['reviewer', 'admin']::content.staff_role[]) then
    raise exception 'Reviewer or admin role required';
  end if;

  select * into v
  from content.question_versions
  where id = p_version_id
  for update;

  if not found then
    raise exception 'Question version not found: %', p_version_id;
  end if;

  select string_agg(rule_code || ': ' || details, '; ' order by rule_code)
  into failures
  from content.validate_question_version(p_version_id)
  where not passed;

  if failures is not null then
    raise exception 'Question version is not publishable: %', failures;
  end if;

  perform set_config('content.publish_context', '1', true);

  update content.question_versions
  set status = 'corrected'
  where question_id = v.question_id
    and id <> v.id
    and status = 'published';

  update content.question_versions
  set status = 'published',
      published_at = coalesce(published_at, now()),
      disputed_at = null,
      archived_at = null
  where id = v.id;

  update content.questions
  set current_published_version_id = v.id
  where id = v.question_id;

  if actor is not null then
    insert into content.content_reviews(question_version_id, kind, decision, reviewer_id, notes)
    values (v.id, 'final_publication', 'approved', actor, 'Published through controlled database function');
  end if;

  insert into content.publication_events(question_version_id, event_type, actor_id)
  values (
    v.id,
    case when v.published_at is null then 'published' else 'republished' end,
    actor
  );

  perform set_config('content.publish_context', '0', true);
  return v.id;
end;
$$;

create or replace function content.suppress_question_version(p_version_id uuid, p_reason text)
returns uuid
language plpgsql
security definer
set search_path = content, public
as $$
declare
  v content.question_versions%rowtype;
  actor uuid := auth.uid();
begin
  if not content.is_staff(array['reviewer', 'admin']::content.staff_role[]) then
    raise exception 'Reviewer or admin role required';
  end if;

  select * into v from content.question_versions where id = p_version_id for update;
  if not found then
    raise exception 'Question version not found: %', p_version_id;
  end if;
  if v.status <> 'published' then
    raise exception 'Only published content can be suppressed';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Suppression reason is required';
  end if;

  perform set_config('content.publish_context', '1', true);

  update content.question_versions
  set status = 'disputed', disputed_at = now()
  where id = v.id;

  update content.questions
  set current_published_version_id = null
  where id = v.question_id and current_published_version_id = v.id;

  insert into content.publication_events(question_version_id, event_type, actor_id, reason)
  values (v.id, 'disputed', actor, p_reason);

  perform set_config('content.publish_context', '0', true);
  return v.id;
end;
$$;

create or replace function content.archive_question_version(p_version_id uuid, p_reason text)
returns uuid
language plpgsql
security definer
set search_path = content, public
as $$
declare
  v content.question_versions%rowtype;
  actor uuid := auth.uid();
begin
  if not content.is_staff(array['reviewer', 'admin']::content.staff_role[]) then
    raise exception 'Reviewer or admin role required';
  end if;

  select * into v from content.question_versions where id = p_version_id for update;
  if not found then
    raise exception 'Question version not found: %', p_version_id;
  end if;
  if v.status = 'archived' then
    return v.id;
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Archive reason is required';
  end if;

  perform set_config('content.publish_context', '1', true);

  update content.question_versions
  set status = 'archived', archived_at = now()
  where id = v.id;

  update content.questions
  set current_published_version_id = null
  where id = v.question_id and current_published_version_id = v.id;

  insert into content.publication_events(question_version_id, event_type, actor_id, reason)
  values (v.id, 'archived', actor, p_reason);

  perform set_config('content.publish_context', '0', true);
  return v.id;
end;
$$;
