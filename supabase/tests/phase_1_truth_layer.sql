begin;

create extension if not exists pgtap;
select plan(34);

select has_schema('content', 'content schema exists');
select has_table('content', 'questions', 'stable questions table exists');
select has_table('content', 'question_versions', 'immutable versions table exists');
select has_table('content', 'question_sources', 'provenance links table exists');
select has_table('content', 'content_reviews', 'review log exists');
select has_table('content', 'corrections', 'correction impact table exists');
select has_function('content', 'validate_question_version', array['uuid'], 'publication validator exists');
select has_function('content', 'publish_question_version', array['uuid'], 'controlled publish function exists');
select has_function('content', 'suppress_question_version', array['uuid', 'text'], 'suppression function exists');
select has_view('content', 'api_published_questions', 'learner-safe published view exists');
select hasnt_column('content', 'api_published_questions', 'answer_payload', 'learner-safe view omits canonical answers');

insert into content.exams(id, name, jurisdiction, active)
values ('test_exam', '{"en":"Test Exam"}', 'test', true);

insert into content.exam_versions(id, exam_id, label, active)
values ('test_exam_v1', 'test_exam', 'Version 1', true);

insert into content.syllabus_nodes(id, exam_version_id, node_kind, title, path, depth)
values ('test_exam_v1:topic', 'test_exam_v1', 'topic', '{"en":"Topic"}', 'topic', 0);

insert into content.source_documents(id, kind, title, source_uri)
values ('00000000-0000-0000-0000-000000000010', 'official_question_paper', 'Test source', 'https://example.invalid/test');

insert into content.questions(id, stable_key, exam_version_id)
values ('00000000-0000-0000-0000-000000000020', 'q_test_truth', 'test_exam_v1');

insert into content.question_versions(
  id, version_key, question_id, version_number, content_class, status,
  question_type, original_language, prompt, answer_payload
) values (
  '00000000-0000-0000-0000-000000000030', 'qv_test_truth_v1',
  '00000000-0000-0000-0000-000000000020', 1, 'experimental', 'publishable',
  'direct_mcq', 'en', '{"en":"Question?"}', '{"correct_option_keys":["a"]}'
);

select results_eq(
  $$select passed from content.validate_question_version('00000000-0000-0000-0000-000000000030') where rule_code = 'not_experimental'$$,
  array[false],
  'experimental content fails publication validation'
);

select results_eq(
  $$select passed from content.validate_question_version('00000000-0000-0000-0000-000000000030') where rule_code = 'source_present'$$,
  array[false],
  'missing source fails publication validation'
);

select results_eq(
  $$select passed from content.validate_question_version('00000000-0000-0000-0000-000000000030') where rule_code = 'primary_syllabus_mapping'$$,
  array[false],
  'missing primary syllabus mapping fails validation'
);

update content.question_versions
set shared_payload = '{"nested":{"correct_option_keys":["a"]}}'
where id = '00000000-0000-0000-0000-000000000030';

select results_eq(
  $$select passed from content.validate_question_version('00000000-0000-0000-0000-000000000030') where rule_code = 'no_answer_leak_in_public_payload'$$,
  array[false],
  'nested answer-bearing keys fail publication validation'
);

update content.question_versions
set shared_payload = '{}'::jsonb
where id = '00000000-0000-0000-0000-000000000030';

select throws_ok(
  $$insert into content.question_versions(
      version_key, question_id, version_number, content_class, status,
      question_type, original_language, prompt, answer_payload
    ) values (
      'qv_direct_published', '00000000-0000-0000-0000-000000000020', 99,
      'curated', 'published', 'direct_mcq', 'en', '{"en":"No"}', '{}'
    )$$,
  'P0001',
  'Question versions cannot be inserted directly into a terminal/public state',
  'terminal/public state cannot be inserted directly'
);

select throws_ok(
  $$update content.question_versions set status = 'published' where id = '00000000-0000-0000-0000-000000000030'$$,
  'P0001',
  'Direct terminal/public status transitions are prohibited; use the content workflow functions',
  'direct publication update is rejected'
);

update content.question_versions
set content_class = 'curated',
    status = 'language_reviewed',
    answer_verified_at = now(),
    explanation_verified_at = now(),
    language_reviewed_at = now(),
    rendering_validated_at = now()
where id = '00000000-0000-0000-0000-000000000030';

insert into content.question_options(question_version_id, option_key, position, text)
values
  ('00000000-0000-0000-0000-000000000030', 'a', 0, '{"en":"A"}'),
  ('00000000-0000-0000-0000-000000000030', 'b', 1, '{"en":"B"}');

insert into content.question_sources(question_version_id, source_document_id, claim_role)
values ('00000000-0000-0000-0000-000000000030', '00000000-0000-0000-0000-000000000010', 'multiple');

insert into content.question_syllabus_mappings(question_version_id, syllabus_node_id, is_primary)
values ('00000000-0000-0000-0000-000000000030', 'test_exam_v1:topic', true);

insert into content.explanations(question_version_id, language, body, verified)
values ('00000000-0000-0000-0000-000000000030', 'en', '{"summary":"Because A is correct."}', true);

update content.question_versions
set status = 'publishable'
where id = '00000000-0000-0000-0000-000000000030';

select is_empty(
  $$select 1 from content.validate_question_version('00000000-0000-0000-0000-000000000030') where not passed$$,
  'fully prepared curated version passes all publication rules'
);

select lives_ok(
  $$select content.publish_question_version('00000000-0000-0000-0000-000000000030')$$,
  'controlled publication succeeds'
);

select is(
  (select current_published_version_id from content.questions where id = '00000000-0000-0000-0000-000000000020'),
  '00000000-0000-0000-0000-000000000030'::uuid,
  'controlled publication updates the stable current-version pointer'
);

select throws_ok(
  $$update content.question_versions set prompt = '{"en":"Changed after publication"}' where id = '00000000-0000-0000-0000-000000000030'$$,
  'P0001',
  'Published or terminal question versions are immutable; create a successor version',
  'published payload is immutable'
);

insert into content.question_versions(
  id, version_key, question_id, version_number, supersedes_version_id,
  content_class, status, question_type, original_language, prompt, answer_payload
) values (
  '00000000-0000-0000-0000-000000000031', 'qv_test_truth_v2',
  '00000000-0000-0000-0000-000000000020', 2,
  '00000000-0000-0000-0000-000000000030',
  'curated', 'imported', 'direct_mcq', 'en',
  '{"en":"Corrected question?"}', '{"correct_option_keys":["a"]}'
);

select throws_ok(
  $$update content.question_options set text = '{"en":"Mutated"}' where question_version_id = '00000000-0000-0000-0000-000000000030' and option_key = 'a'$$,
  'P0001',
  'Child records of a published or terminal question version are immutable; create a successor version',
  'published option payload is immutable'
);

select throws_ok(
  $$update content.question_options
      set question_version_id = '00000000-0000-0000-0000-000000000031'
      where question_version_id = '00000000-0000-0000-0000-000000000030' and option_key = 'a'$$,
  'P0001',
  'Child records of a published or terminal question version are immutable; create a successor version',
  'published child rows cannot be moved to a draft version'
);

select throws_ok(
  $$update content.source_documents set title = 'Mutated source' where id = '00000000-0000-0000-0000-000000000010'$$,
  'P0001',
  'A source linked to published or terminal content is immutable; create a new source record',
  'published source record is immutable'
);

select throws_ok(
  $$update content.questions set current_published_version_id = '00000000-0000-0000-0000-000000000031' where id = '00000000-0000-0000-0000-000000000020'$$,
  'P0001',
  'Current published pointer must reference a published version of the same question',
  'current pointer cannot target a draft successor'
);

select throws_ok(
  $$update content.questions set stable_key = 'q_changed_identity' where id = '00000000-0000-0000-0000-000000000020'$$,
  'P0001',
  'Stable question identity and exam version cannot change after versions exist',
  'stable question identity is immutable once versions exist'
);

select is(
  (select supersedes_version_id from content.question_versions where id = '00000000-0000-0000-0000-000000000031'),
  '00000000-0000-0000-0000-000000000030'::uuid,
  'successor preserves correction lineage'
);

select throws_ok(
  $$insert into content.question_versions(
      version_key, question_id, version_number, supersedes_version_id,
      content_class, question_type, original_language, prompt, answer_payload
    ) values (
      'qv_bad_successor', '00000000-0000-0000-0000-000000000020', 1,
      '00000000-0000-0000-0000-000000000030',
      'curated', 'direct_mcq', 'en', '{"en":"Bad"}', '{}'
    )$$,
  'P0001',
  'A successor version number must be greater than the superseded version',
  'successor version number must increase'
);

select col_is_pk('content', 'questions', 'id', 'questions use UUID primary key');
select col_is_pk('content', 'question_versions', 'id', 'question versions use UUID primary key');
select has_index('content', 'question_syllabus_mappings', 'question_one_primary_syllabus_idx', 'one-primary-mapping index exists');
select has_trigger('content', 'question_versions', 'question_versions_prevent_locked_mutation', 'immutability trigger exists');
select has_trigger('content', 'question_versions', 'question_versions_enforce_status', 'status transition trigger exists');
select has_trigger('content', 'content_reviews', 'content_reviews_append_only', 'reviews are append-only');

select * from finish();
rollback;
