-- Parikshai Phase 2 focused workflow migration.

create or replace function learning.create_practice_session(
  p_user_id uuid,p_anonymous_id uuid,p_anonymous_secret text,p_kind learning.session_kind,
  p_exam_id text,p_topic_node_id text,p_language text,p_question_count integer,p_client_session_key uuid
) returns jsonb language plpgsql security definer set search_path=learning,content,public as $$
declare s learning.practice_sessions%rowtype; old learning.practice_sessions%rowtype; n integer;
begin
  if num_nonnulls(p_user_id,p_anonymous_id)<>1 then raise exception 'Exactly one learner identity is required'; end if;
  if p_user_id is null and not learning.owner_matches(null,p_anonymous_id,null,p_anonymous_id,p_anonymous_secret) then raise exception 'Anonymous credentials are invalid'; end if;
  if p_question_count not between 1 and 50 then raise exception 'Question count is out of range'; end if;
  if p_kind='topic' and p_topic_node_id is null then raise exception 'Topic sessions require a topic node'; end if;
  select * into old from learning.practice_sessions where client_session_key=p_client_session_key;
  if found then
    if not learning.owner_matches(old.owner_user_id,old.owner_anonymous_id,p_user_id,p_anonymous_id,p_anonymous_secret) then raise exception 'Client session key belongs to a different learner'; end if;
    return jsonb_build_object('session_id',old.id,'status',old.status,'replayed',true);
  end if;
  insert into learning.practice_sessions(owner_user_id,owner_anonymous_id,kind,status,exam_id,topic_node_id,language,requested_question_count,client_session_key,started_at)
  values(p_user_id,p_anonymous_id,p_kind,'active',p_exam_id,p_topic_node_id,p_language,p_question_count,p_client_session_key,now()) returning * into s;
  insert into learning.session_questions(session_id,ordinal,question_version_id,public_payload_snapshot)
  select s.id,row_number() over(order by encode(digest(q.question_version_id::text||s.id::text,'sha256'),'hex'))::int,q.question_version_id,to_jsonb(q)
  from content.api_published_questions q join content.exam_versions ev on ev.id=q.exam_version_id
  where ev.exam_id=p_exam_id and (p_topic_node_id is null or exists(
    select 1 from content.question_syllabus_mappings m where m.question_version_id=q.question_version_id and m.syllabus_node_id=p_topic_node_id))
  order by encode(digest(q.question_version_id::text||s.id::text,'sha256'),'hex') limit p_question_count;
  get diagnostics n=row_count;
  if n<>p_question_count then raise exception 'Insufficient eligible published questions: requested %, found %',p_question_count,n; end if;
  insert into learning.session_recovery(session_id,cursor_ordinal) values(s.id,1);
  return jsonb_build_object('session_id',s.id,'status',s.status,'kind',s.kind,'question_count',n,'replayed',false);
end; $$;

create or replace function learning.get_session_snapshot(
  p_user_id uuid,p_anonymous_id uuid,p_anonymous_secret text,p_session_id uuid
) returns jsonb language plpgsql stable security definer set search_path=learning,public as $$
declare s learning.practice_sessions%rowtype;
begin
  select * into s from learning.practice_sessions where id=p_session_id;
  if not found then raise exception 'Session not found'; end if;
  if not learning.owner_matches(s.owner_user_id,s.owner_anonymous_id,p_user_id,p_anonymous_id,p_anonymous_secret) then raise exception 'Session does not belong to learner'; end if;
  return jsonb_build_object('session_id',s.id,'kind',s.kind,'status',s.status,'exam_id',s.exam_id,'topic_node_id',s.topic_node_id,
    'language',s.language,'question_count',s.requested_question_count,
    'answered_count',(select count(*) from learning.session_questions where session_id=s.id and status='answered'),
    'cursor_ordinal',coalesce((select cursor_ordinal from learning.session_recovery where session_id=s.id),1),
    'created_at',s.created_at,'last_activity_at',s.last_activity_at);
end; $$;

create or replace function learning.get_session_question(
  p_user_id uuid,p_anonymous_id uuid,p_anonymous_secret text,p_session_id uuid,p_ordinal integer
) returns jsonb language plpgsql stable security definer set search_path=learning,content,public as $$
declare s learning.practice_sessions%rowtype; q learning.session_questions%rowtype;
begin
  select * into s from learning.practice_sessions where id=p_session_id;
  if not found then raise exception 'Session not found'; end if;
  if not learning.owner_matches(s.owner_user_id,s.owner_anonymous_id,p_user_id,p_anonymous_id,p_anonymous_secret) then raise exception 'Session does not belong to learner'; end if;
  select * into q from learning.session_questions where session_id=p_session_id and ordinal=p_ordinal;
  if not found then raise exception 'Session question not found'; end if;
  if content.jsonb_contains_key_recursive(q.public_payload_snapshot,array['answer','answers','answer_key','correct','correct_answer','correct_option_ids','rationale','explanation','explanation_body']) then
    raise exception 'Answer boundary violation in session snapshot';
  end if;
  return jsonb_build_object('session_question_id',q.id,'ordinal',q.ordinal,'status',q.status,'question',q.public_payload_snapshot);
end; $$;
