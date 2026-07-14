begin;
create extension if not exists pgtap;
select plan(39);

select has_schema('learning', 'learning schema exists');
select has_table('learning', 'learner_profiles', 'learner profiles exist');
select has_table('learning', 'anonymous_identities', 'anonymous identities exist');
select has_table('learning', 'identity_migrations', 'identity migrations exist');
select has_table('learning', 'practice_sessions', 'practice sessions exist');
select has_table('learning', 'session_questions', 'session question snapshots exist');
select has_table('learning', 'answer_submissions', 'answer submissions exist');
select has_table('learning', 'answer_results', 'answer results exist');
select has_table('learning', 'bookmarks', 'bookmarks exist');
select has_table('learning', 'session_recovery', 'session recovery exists');
select has_table('learning', 'idempotency_receipts', 'idempotency receipts exist');
select has_table('learning', 'evidence_events', 'evidence events exist');

select has_function('learning', 'create_anonymous_identity', 'anonymous identity creation is available');
select has_function('learning', 'attach_anonymous_identity', 'anonymous attachment is available');
select has_function('learning', 'upsert_learner_profile', 'profile upsert is available');
select has_function('learning', 'create_practice_session', 'session creation is available');
select has_function('learning', 'get_session_snapshot', 'session restore snapshot is available');
select has_function('learning', 'get_session_question', 'answer-free question delivery is available');
select has_function('learning', 'submit_answer', 'atomic answer submission is available');
select has_function('learning', 'get_answer_review', 'post-submission review is available');
select has_function('learning', 'complete_practice_session', 'session completion is available');
select has_function('learning', 'restore_learner_state', 'learner restoration is available');
select has_function('learning', 'set_bookmark', 'bookmark workflow is available');
select has_function('learning', 'report_question', 'question reporting is available');

select col_is_pk('learning', 'learner_profiles', 'user_id', 'auth user ID owns permanent profile');
select col_is_pk('learning', 'answer_results', 'submission_id', 'one canonical result per submission');
select has_column('learning', 'session_questions', 'question_version_id', 'session snapshots reference exact versions');
select has_column('learning', 'answer_submissions', 'idempotency_key', 'submissions carry idempotency keys');
select has_column('learning', 'evidence_events', 'syllabus_node_id', 'raw evidence can map to syllabus nodes');

select has_trigger('learning', 'session_questions', 'session_question_answer_boundary', 'session snapshots reject answer-bearing keys');
select has_trigger('learning', 'session_questions', 'session_questions_no_update', 'session snapshot identity is immutable');
select has_trigger('learning', 'answer_submissions', 'submissions_owner_reassignment', 'submission ownership can change only through guarded attachment');
select has_trigger('learning', 'answer_submissions', 'submissions_no_delete', 'submissions cannot be deleted');
select has_trigger('learning', 'evidence_events', 'evidence_owner_reassignment', 'evidence ownership can change only through guarded attachment');
select has_trigger('learning', 'evidence_events', 'evidence_no_delete', 'evidence cannot be deleted');
select has_trigger('learning', 'idempotency_receipts', 'receipts_owner_reassignment', 'receipt ownership can change only through guarded attachment');
select has_trigger('learning', 'idempotency_receipts', 'receipts_no_delete', 'receipts cannot be deleted');

select hasnt_table_privilege('authenticated', 'learning.answer_results', 'SELECT', 'authenticated clients cannot query canonical results directly');
select hasnt_table_privilege('anon', 'learning.answer_submissions', 'INSERT', 'anonymous clients cannot forge submissions directly');

select * from finish();
rollback;
