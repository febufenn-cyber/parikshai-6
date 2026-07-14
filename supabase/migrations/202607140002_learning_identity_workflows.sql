-- Parikshai Phase 2 focused workflow migration.

create or replace function learning.owner_matches(
  p_owner_user_id uuid, p_owner_anonymous_id uuid,
  p_user_id uuid, p_anonymous_id uuid, p_anonymous_secret text
) returns boolean language sql stable security definer set search_path=learning,public as $$
  select case
    when p_user_id is not null then p_owner_user_id=p_user_id and p_owner_anonymous_id is null
    else p_anonymous_id is not null and p_anonymous_secret is not null
      and p_owner_anonymous_id=p_anonymous_id
      and exists(select 1 from learning.anonymous_identities a where a.id=p_anonymous_id and a.state='active' and a.secret_hash=digest(p_anonymous_secret,'sha256'))
  end;
$$;

create or replace function learning.create_anonymous_identity(p_secret text)
returns jsonb language plpgsql security definer set search_path=learning,public as $$
declare v_id uuid;
begin
  if coalesce(length(p_secret),0)<32 then raise exception 'Anonymous secret must contain at least 32 characters'; end if;
  insert into learning.anonymous_identities(secret_hash) values(digest(p_secret,'sha256')) returning id into v_id;
  return jsonb_build_object('anonymous_id',v_id);
end; $$;

create or replace function learning.attach_anonymous_identity(
  p_user_id uuid,p_anonymous_id uuid,p_secret text,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path=learning,public as $$
declare a learning.anonymous_identities%rowtype; m learning.identity_migrations%rowtype; n_sessions bigint; n_bookmarks bigint;
begin
  if p_user_id is null then raise exception 'Authenticated user is required'; end if;
  select * into m from learning.identity_migrations where idempotency_key=p_idempotency_key;
  if found then
    if m.user_id<>p_user_id or m.anonymous_id<>p_anonymous_id then raise exception 'Idempotency key was reused with different identity data'; end if;
    return jsonb_build_object('status',m.status,'anonymous_id',p_anonymous_id,'user_id',p_user_id,'replayed',true);
  end if;
  select * into a from learning.anonymous_identities where id=p_anonymous_id for update;
  if not found or a.secret_hash<>digest(p_secret,'sha256') then raise exception 'Anonymous credentials are invalid'; end if;
  if a.state='attached' then
    if a.attached_user_id<>p_user_id then raise exception 'Anonymous identity is already attached to another account'; end if;
    return jsonb_build_object('status','completed','anonymous_id',p_anonymous_id,'user_id',p_user_id,'replayed',true);
  end if;
  if a.state<>'active' then raise exception 'Anonymous identity is not attachable'; end if;
  insert into learning.learner_profiles(user_id) values(p_user_id) on conflict do nothing;
  perform set_config('learning.identity_migration_context','1',true);
  update learning.practice_sessions set owner_user_id=p_user_id,owner_anonymous_id=null,last_activity_at=now() where owner_anonymous_id=p_anonymous_id;
  get diagnostics n_sessions=row_count;
  insert into learning.bookmarks(owner_user_id,question_version_id,created_at)
    select p_user_id,question_version_id,created_at from learning.bookmarks where owner_anonymous_id=p_anonymous_id on conflict do nothing;
  get diagnostics n_bookmarks=row_count;
  delete from learning.bookmarks where owner_anonymous_id=p_anonymous_id;
  update learning.answer_submissions set owner_user_id=p_user_id,owner_anonymous_id=null where owner_anonymous_id=p_anonymous_id;
  update learning.evidence_events set owner_user_id=p_user_id,owner_anonymous_id=null where owner_anonymous_id=p_anonymous_id;
  update learning.idempotency_receipts set owner_user_id=p_user_id,owner_anonymous_id=null where owner_anonymous_id=p_anonymous_id;
  update learning.anonymous_identities set state='attached',attached_user_id=p_user_id,attached_at=now(),last_seen_at=now() where id=p_anonymous_id;
  insert into learning.identity_migrations(anonymous_id,user_id,idempotency_key,status,conflict_policy,details)
    values(p_anonymous_id,p_user_id,p_idempotency_key,'completed','merge_non_destructive',jsonb_build_object('sessions_migrated',n_sessions,'bookmarks_migrated',n_bookmarks));
  return jsonb_build_object('status','completed','anonymous_id',p_anonymous_id,'user_id',p_user_id,'sessions_migrated',n_sessions,'bookmarks_migrated',n_bookmarks,'replayed',false);
end; $$;

create or replace function learning.upsert_learner_profile(
  p_user_id uuid,p_display_name text,p_preferred_language text,p_exam_id text,p_onboarding jsonb
) returns jsonb language plpgsql security definer set search_path=learning,content,public as $$
declare p learning.learner_profiles%rowtype;
begin
  if p_user_id is null then raise exception 'Authenticated user is required'; end if;
  insert into learning.learner_profiles(user_id,display_name,preferred_language,exam_id,onboarding)
  values(p_user_id,nullif(btrim(p_display_name),''),p_preferred_language,p_exam_id,coalesce(p_onboarding,'{}'::jsonb))
  on conflict(user_id) do update set display_name=excluded.display_name,preferred_language=excluded.preferred_language,
    exam_id=excluded.exam_id,onboarding=learning.learner_profiles.onboarding||excluded.onboarding,updated_at=now()
  returning * into p;
  return to_jsonb(p);
end; $$;
