-- Parikshai Phase 1: learner-safe views, RLS, and grants.

create view content.api_exams
with (security_barrier = true)
as
select e.id, e.name, e.jurisdiction
from content.exams e
where e.active;

create view content.api_syllabus_nodes
with (security_barrier = true)
as
select
  sn.id,
  sn.exam_version_id,
  sn.parent_id,
  sn.node_kind,
  sn.code,
  sn.title,
  sn.path,
  sn.depth,
  sn.sort_order,
  sn.relevance_from,
  sn.relevance_until
from content.syllabus_nodes sn
join content.exam_versions ev on ev.id = sn.exam_version_id
join content.exams e on e.id = ev.exam_id
where e.active
  and ev.active
  and sn.is_active
  and (sn.relevance_from is null or sn.relevance_from <= current_date)
  and (sn.relevance_until is null or sn.relevance_until >= current_date);

create view content.api_published_questions
with (security_barrier = true)
as
select
  q.id as question_id,
  q.stable_key,
  q.exam_version_id,
  qv.id as question_version_id,
  qv.version_key,
  qv.version_number,
  qv.content_class,
  qv.question_type,
  qv.original_language,
  qv.prompt,
  qv.shared_payload,
  qv.difficulty,
  qv.published_at,
  qv.expires_at,
  case when p.id is null then null else jsonb_build_object(
    'passage_id', p.id,
    'stable_key', p.stable_key,
    'original_language', p.original_language,
    'content', p.content
  ) end as passage,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'option_key', qo.option_key,
          'position', qo.position,
          'text', qo.text
        ) order by qo.position
      )
      from content.question_options qo
      where qo.question_version_id = qv.id
    ),
    '[]'::jsonb
  ) as options,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'asset_id', qa.id,
          'asset_kind', qa.asset_kind,
          'storage_path', qa.storage_path,
          'sha256', qa.sha256,
          'alt_text', qa.alt_text,
          'metadata', qa.metadata
        ) order by qa.created_at
      )
      from content.question_assets qa
      where qa.question_version_id = qv.id
    ),
    '[]'::jsonb
  ) as assets,
  coalesce(
    (
      select jsonb_agg(distinct e.language)
      from content.explanations e
      where e.question_version_id = qv.id and e.verified
    ),
    '[]'::jsonb
  ) as verified_explanation_languages
from content.questions q
join content.question_versions qv on qv.id = q.current_published_version_id
left join content.passages p on p.id = qv.passage_id
where qv.status = 'published'
  and (qv.published_at is null or qv.published_at <= now())
  and (qv.valid_from is null or qv.valid_from <= now())
  and (qv.valid_until is null or qv.valid_until > now())
  and (qv.expires_at is null or qv.expires_at > now());

create view content.editorial_queue
with (security_invoker = true)
as
select
  q.stable_key,
  qv.id as question_version_id,
  qv.version_key,
  qv.version_number,
  qv.content_class,
  qv.status,
  qv.question_type,
  qv.created_at,
  case qv.status
    when 'imported' then 'structure'
    when 'structurally_valid' then 'answer'
    when 'answer_verified' then 'explanation'
    when 'explanation_verified' then 'language'
    when 'language_reviewed' then 'rendering/final_publication'
    when 'publishable' then 'final_publication'
    when 'disputed' then 'dispute'
    else null
  end as next_review
from content.question_versions qv
join content.questions q on q.id = qv.question_id
where qv.status not in ('published', 'corrected', 'archived');

create view content.coverage_summary
with (security_invoker = true)
as
select
  sn.exam_version_id,
  sn.id as syllabus_node_id,
  sn.path,
  qv.content_class,
  qv.status,
  count(distinct qv.id) as question_version_count,
  count(distinct qv.id) filter (
    where qv.status in ('publishable', 'published', 'disputed', 'corrected')
  ) as reviewed_count,
  count(distinct qv.question_type) as format_diversity
from content.syllabus_nodes sn
left join content.question_syllabus_mappings qsm on qsm.syllabus_node_id = sn.id
left join content.question_versions qv on qv.id = qsm.question_version_id
group by sn.exam_version_id, sn.id, sn.path, qv.content_class, qv.status;

create or replace function content.normalize_question_report_insert()
returns trigger
language plpgsql
security definer
set search_path = content, public
as $$
begin
  if not content.is_staff() then
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

create trigger question_reports_normalize_learner_insert
before insert on content.question_reports
for each row execute function content.normalize_question_report_insert();

alter table content.staff_users enable row level security;
alter table content.exams enable row level security;
alter table content.exam_versions enable row level security;
alter table content.syllabus_nodes enable row level security;
alter table content.source_documents enable row level security;
alter table content.passages enable row level security;
alter table content.questions enable row level security;
alter table content.question_versions enable row level security;
alter table content.question_options enable row level security;
alter table content.question_assets enable row level security;
alter table content.question_syllabus_mappings enable row level security;
alter table content.question_sources enable row level security;
alter table content.explanations enable row level security;
alter table content.content_reviews enable row level security;
alter table content.generation_runs enable row level security;
alter table content.validator_results enable row level security;
alter table content.question_reports enable row level security;
alter table content.corrections enable row level security;
alter table content.publication_events enable row level security;

create policy staff_users_admin_select on content.staff_users
for select to authenticated
using (content.is_staff(array['admin']::content.staff_role[]) or user_id = auth.uid());

create policy staff_users_admin_write on content.staff_users
for all to authenticated
using (content.is_staff(array['admin']::content.staff_role[]))
with check (content.is_staff(array['admin']::content.staff_role[]));

create policy exams_public_read on content.exams
for select to anon, authenticated
using (active or content.is_staff());

create policy exam_versions_public_read on content.exam_versions
for select to anon, authenticated
using (active or content.is_staff());

create policy syllabus_public_read on content.syllabus_nodes
for select to anon, authenticated
using (is_active or content.is_staff());

create policy questions_staff_read on content.questions
for select to authenticated
using (content.is_staff());

create policy question_versions_staff_read on content.question_versions
for select to authenticated
using (content.is_staff());

create policy options_staff_read on content.question_options
for select to authenticated
using (content.is_staff());

create policy assets_staff_read on content.question_assets
for select to authenticated
using (content.is_staff());

create policy mappings_staff_read on content.question_syllabus_mappings
for select to authenticated
using (content.is_staff());

create policy source_links_staff_read on content.question_sources
for select to authenticated
using (content.is_staff());

create policy source_documents_staff_read on content.source_documents
for select to authenticated
using (content.is_staff());

create policy passages_staff_read on content.passages
for select to authenticated
using (content.is_staff());

create policy explanations_staff_read on content.explanations
for select to authenticated
using (content.is_staff());

create policy reports_learner_insert on content.question_reports
for insert to authenticated
with check (reporter_id = auth.uid() and content.can_read_version(question_version_id));

create policy reports_learner_read on content.question_reports
for select to authenticated
using (reporter_id = auth.uid() or content.is_staff());

create policy reports_staff_update on content.question_reports
for update to authenticated
using (content.is_staff(array['reviewer', 'admin']::content.staff_role[]))
with check (content.is_staff(array['reviewer', 'admin']::content.staff_role[]));

create policy exams_staff_write on content.exams
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy exam_versions_staff_write on content.exam_versions
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy syllabus_staff_write on content.syllabus_nodes
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy source_documents_staff_write on content.source_documents
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy passages_staff_write on content.passages
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy questions_staff_write on content.questions
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy question_versions_staff_write on content.question_versions
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy options_staff_write on content.question_options
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy assets_staff_write on content.question_assets
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy mappings_staff_write on content.question_syllabus_mappings
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy source_links_staff_write on content.question_sources
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy explanations_staff_write on content.explanations
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy reviews_staff_all on content.content_reviews
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy generation_staff_all on content.generation_runs
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy validators_staff_all on content.validator_results
for all to authenticated using (content.is_staff()) with check (content.is_staff());
create policy corrections_staff_all on content.corrections
for all to authenticated using (content.is_staff(array['reviewer', 'admin']::content.staff_role[]))
with check (content.is_staff(array['reviewer', 'admin']::content.staff_role[]));
create policy publication_events_staff_read on content.publication_events
for select to authenticated using (content.is_staff());

revoke all on schema content from public;
grant usage on schema content to anon, authenticated, service_role;

grant select on content.api_exams, content.api_syllabus_nodes, content.api_published_questions
  to anon, authenticated;

revoke all on content.question_reports from authenticated;
grant select on content.question_reports to authenticated;
grant insert (question_version_id, reason_code, description) on content.question_reports to authenticated;

grant all on all tables in schema content to service_role;
grant all on all sequences in schema content to service_role;

grant select on content.editorial_queue, content.coverage_summary to service_role;

grant execute on function content.publish_question_version(uuid) to authenticated;
grant execute on function content.suppress_question_version(uuid, text) to authenticated;
grant execute on function content.archive_question_version(uuid, text) to authenticated;
grant execute on function content.validate_question_version(uuid) to authenticated;
grant execute on function content.my_staff_role() to authenticated;

comment on function content.publish_question_version(uuid) is 'The only supported transition into published status.';
comment on function content.suppress_question_version(uuid, text) is 'Immediately removes a published version from learner retrieval while preserving history.';
comment on function content.archive_question_version(uuid, text) is 'Archives a version through an audited terminal-state transition.';
comment on table content.corrections is 'Links immutable old and new versions and tracks downstream learner impact repair.';
