-- Parikshai Phase 2 focused workflow migration.

create or replace function learning.submit_answer(
  p_user_id uuid,p_anonymous_id uuid,p_anonymous_secret text,p_session_id uuid,p_session_question_id uuid,
  p_selected_option_ids text[],p_response_payload jsonb,p_elapsed_ms integer,p_client_submitted_at timestamptz,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path=learning,content,public as $$
declare s learning.practice_sessions%rowtype; q learning.session_questions%rowtype; v content.question_versions%rowtype;
declare submission_id uuid; selected_ids text[]; correct_ids text[]; ok boolean; explanation jsonb; sources jsonb; response jsonb; request_hash bytea;
declare receipt learning.idempotency_receipts%rowtype; primary_node text;
begin
  selected_ids:=array(select distinct x from unnest(coalesce(p_selected_option_ids,'{}')) x order by x);
  request_hash:=digest(jsonb_build_object('session_id',p_session_id,'session_question_id',p_session_question_id,'selected_option_ids',selected_ids,'response_payload',coalesce(p_response_payload,'{}'::jsonb),'elapsed_ms',p_elapsed_ms)::text,'sha256');
  select * into receipt from learning.idempotency_receipts where idempotency_key=p_idempotency_key;
  if found then
    if receipt.operation<>'submit_answer' or receipt.request_hash<>request_hash
      or not learning.owner_matches(receipt.owner_user_id,receipt.owner_anonymous_id,p_user_id,p_anonymous_id,p_anonymous_secret) then raise exception 'Idempotency key conflict'; end if;
    return receipt.response_payload||jsonb_build_object('replayed',true);
  end if;
  select * into s from learning.practice_sessions where id=p_session_id for update;
  if not found then raise exception 'Session not found'; end if;
  if not learning.owner_matches(s.owner_user_id,s.owner_anonymous_id,p_user_id,p_anonymous_id,p_anonymous_secret) then raise exception 'Session does not belong to learner'; end if;
  if s.status<>'active' then raise exception 'Session is not active'; end if;
  select * into q from learning.session_questions where id=p_session_question_id and session_id=p_session_id for update;
  if not found then raise exception 'Question does not belong to session'; end if;
  if q.status='answered' then raise exception 'Question already has a final answer'; end if;
  select * into v from content.question_versions where id=q.question_version_id;
  if v.status<>'published' or v.answer_verified_at is null then raise exception 'Question version is not eligible for scoring'; end if;
  select coalesce(array_agg(value order by value),'{}') into correct_ids from jsonb_array_elements_text(coalesce(v.answer_payload->'correct_option_ids','[]'::jsonb)) value;
  if cardinality(correct_ids)=0 then raise exception 'Verified answer is missing correct option IDs'; end if;
  ok:=selected_ids=correct_ids;
  select e.body into explanation from content.explanations e where e.question_version_id=v.id and e.verified
    order by (e.language=s.language) desc,(e.language=v.original_language) desc,case e.explanation_level when 'exam_focused' then 0 when 'simple' then 1 else 2 end limit 1;
  explanation:=coalesce(explanation,'{}'::jsonb);
  select coalesce(jsonb_agg(jsonb_build_object('source_kind',d.kind,'title',d.title,'locator',x.source_locator,'claim_role',x.claim_role,'effective_from',d.effective_from,'effective_until',d.effective_until)),'[]'::jsonb) into sources
    from content.question_sources x join content.source_documents d on d.id=x.source_document_id
    where x.question_version_id=v.id and x.claim_role in('answer','explanation','multiple');
  insert into learning.answer_submissions(session_id,session_question_id,owner_user_id,owner_anonymous_id,idempotency_key,selected_option_ids,response_payload,elapsed_ms,client_submitted_at,request_hash)
    values(p_session_id,p_session_question_id,s.owner_user_id,s.owner_anonymous_id,p_idempotency_key,selected_ids,coalesce(p_response_payload,'{}'::jsonb),p_elapsed_ms,p_client_submitted_at,request_hash)
    returning id into submission_id;
  insert into learning.answer_results(submission_id,question_version_id,scoring_status,is_correct,score,correct_option_ids,answer_snapshot,explanation_snapshot,provenance_snapshot)
    values(submission_id,v.id,'scored',ok,case when ok then 1 else 0 end,correct_ids,jsonb_build_object('correct_option_ids',correct_ids),explanation,sources);
  update learning.session_questions set status='answered',answered_at=now() where id=q.id;
  update learning.practice_sessions set last_activity_at=now() where id=s.id;
  insert into learning.session_recovery(session_id,cursor_ordinal,state_version) values(s.id,least(q.ordinal+1,s.requested_question_count),1)
    on conflict(session_id) do update set cursor_ordinal=greatest(learning.session_recovery.cursor_ordinal,excluded.cursor_ordinal),state_version=learning.session_recovery.state_version+1,updated_at=now();
  select syllabus_node_id into primary_node from content.question_syllabus_mappings where question_version_id=v.id and is_primary limit 1;
  insert into learning.evidence_events(owner_user_id,owner_anonymous_id,session_id,session_question_id,submission_id,question_version_id,syllabus_node_id,is_correct,score,elapsed_ms)
    values(s.owner_user_id,s.owner_anonymous_id,s.id,q.id,submission_id,v.id,primary_node,ok,case when ok then 1 else 0 end,p_elapsed_ms);
  response:=jsonb_build_object('submission_id',submission_id,'session_question_id',q.id,'question_version_id',v.id,'is_correct',ok,
    'selected_option_ids',selected_ids,'correct_option_ids',correct_ids,'explanation',explanation,'provenance',sources,'scored_at',now(),'replayed',false);
  insert into learning.idempotency_receipts(idempotency_key,owner_user_id,owner_anonymous_id,operation,request_hash,response_payload)
    values(p_idempotency_key,s.owner_user_id,s.owner_anonymous_id,'submit_answer',request_hash,response);
  return response;
end; $$;

create or replace function learning.get_answer_review(
  p_user_id uuid,p_anonymous_id uuid,p_anonymous_secret text,p_session_id uuid,p_ordinal integer
) returns jsonb language plpgsql stable security definer set search_path=learning,public as $$
declare s learning.practice_sessions%rowtype; q learning.session_questions%rowtype; out jsonb;
begin
  select * into s from learning.practice_sessions where id=p_session_id;
  if not found then raise exception 'Session not found'; end if;
  if not learning.owner_matches(s.owner_user_id,s.owner_anonymous_id,p_user_id,p_anonymous_id,p_anonymous_secret) then raise exception 'Session does not belong to learner'; end if;
  select * into q from learning.session_questions where session_id=p_session_id and ordinal=p_ordinal;
  if not found then raise exception 'Session question not found'; end if;
  select jsonb_build_object('session_question_id',q.id,'ordinal',q.ordinal,'selected_option_ids',a.selected_option_ids,'is_correct',r.is_correct,
    'score',r.score,'correct_option_ids',r.correct_option_ids,'explanation',r.explanation_snapshot,'provenance',r.provenance_snapshot,'scoring_status',r.scoring_status)
    into out from learning.answer_submissions a join learning.answer_results r on r.submission_id=a.id where a.session_question_id=q.id and a.is_final;
  if out is null then raise exception 'Answer review is unavailable before submission'; end if;
  return out;
end; $$;

create or replace function learning.complete_practice_session(
  p_user_id uuid,p_anonymous_id uuid,p_anonymous_secret text,p_session_id uuid,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path=learning,public as $$
declare s learning.practice_sessions%rowtype; response jsonb; h bytea; receipt learning.idempotency_receipts%rowtype;
begin
  h:=digest(jsonb_build_object('session_id',p_session_id)::text,'sha256');
  select * into receipt from learning.idempotency_receipts where idempotency_key=p_idempotency_key;
  if found then
    if receipt.operation<>'complete_session' or receipt.request_hash<>h or not learning.owner_matches(receipt.owner_user_id,receipt.owner_anonymous_id,p_user_id,p_anonymous_id,p_anonymous_secret) then raise exception 'Idempotency key conflict'; end if;
    return receipt.response_payload||jsonb_build_object('replayed',true);
  end if;
  select * into s from learning.practice_sessions where id=p_session_id for update;
  if not found then raise exception 'Session not found'; end if;
  if not learning.owner_matches(s.owner_user_id,s.owner_anonymous_id,p_user_id,p_anonymous_id,p_anonymous_secret) then raise exception 'Session does not belong to learner'; end if;
  update learning.practice_sessions set status='completed',completed_at=now(),last_activity_at=now() where id=p_session_id;
  response:=jsonb_build_object('session_id',p_session_id,'status','completed',
    'answered_count',(select count(*) from learning.session_questions where session_id=p_session_id and status='answered'),
    'correct_count',(select count(*) from learning.answer_submissions a join learning.answer_results r on r.submission_id=a.id where a.session_id=p_session_id and r.is_correct),'replayed',false);
  insert into learning.idempotency_receipts(idempotency_key,owner_user_id,owner_anonymous_id,operation,request_hash,response_payload,created_at,expires_at)
    values(p_idempotency_key,s.owner_user_id,s.owner_anonymous_id,'complete_session',h,response,now(),now()+interval '30 days');
  return response;
end; $$;
