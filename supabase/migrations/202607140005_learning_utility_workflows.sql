-- Parikshai Phase 2 focused workflow migration.

create or replace function learning.restore_learner_state(
  p_user_id uuid,p_anonymous_id uuid,p_anonymous_secret text
) returns jsonb language plpgsql stable security definer set search_path=learning,public as $$
begin
  if p_user_id is null and not learning.owner_matches(null,p_anonymous_id,null,p_anonymous_id,p_anonymous_secret) then raise exception 'Anonymous credentials are invalid'; end if;
  return jsonb_build_object(
    'profile',case when p_user_id is null then null else (select to_jsonb(p) from learning.learner_profiles p where p.user_id=p_user_id) end,
    'active_sessions',coalesce((select jsonb_agg(jsonb_build_object('session_id',s.id,'kind',s.kind,'status',s.status,'exam_id',s.exam_id,'language',s.language,'last_activity_at',s.last_activity_at,'cursor_ordinal',coalesce(r.cursor_ordinal,1)) order by s.last_activity_at desc)
      from learning.practice_sessions s left join learning.session_recovery r on r.session_id=s.id
      where s.status in('created','active') and ((p_user_id is not null and s.owner_user_id=p_user_id) or (p_user_id is null and s.owner_anonymous_id=p_anonymous_id))),'[]'::jsonb),
    'bookmarks',coalesce((select jsonb_agg(jsonb_build_object('question_version_id',b.question_version_id,'created_at',b.created_at)) from learning.bookmarks b
      where (p_user_id is not null and b.owner_user_id=p_user_id) or (p_user_id is null and b.owner_anonymous_id=p_anonymous_id)),'[]'::jsonb));
end; $$;

create or replace function learning.set_bookmark(
  p_user_id uuid,p_anonymous_id uuid,p_anonymous_secret text,p_question_version_id uuid,p_active boolean
) returns jsonb language plpgsql security definer set search_path=learning,public as $$
begin
  if p_user_id is null and not learning.owner_matches(null,p_anonymous_id,null,p_anonymous_id,p_anonymous_secret) then raise exception 'Anonymous credentials are invalid'; end if;
  if p_active then insert into learning.bookmarks(owner_user_id,owner_anonymous_id,question_version_id) values(p_user_id,p_anonymous_id,p_question_version_id) on conflict do nothing;
  else delete from learning.bookmarks where question_version_id=p_question_version_id and ((p_user_id is not null and owner_user_id=p_user_id) or (p_user_id is null and owner_anonymous_id=p_anonymous_id)); end if;
  return jsonb_build_object('question_version_id',p_question_version_id,'bookmarked',p_active);
end; $$;

create or replace function learning.report_question(
  p_user_id uuid,p_anonymous_id uuid,p_anonymous_secret text,p_question_version_id uuid,p_reason_code text,p_description text
) returns jsonb language plpgsql security definer set search_path=learning,content,public as $$
declare report_id uuid;
begin
  if p_user_id is null and not learning.owner_matches(null,p_anonymous_id,null,p_anonymous_id,p_anonymous_secret) then raise exception 'Anonymous credentials are invalid'; end if;
  if p_reason_code!~'^[a-z0-9_]{2,64}$' then raise exception 'Invalid reason code'; end if;
  perform set_config('learning.report_context','1',true);
  insert into content.question_reports(question_version_id,reporter_id,reason_code,description)
    values(p_question_version_id,p_user_id,p_reason_code,left(p_description,2000)) returning id into report_id;
  return jsonb_build_object('report_id',report_id,'status','open');
end; $$;
