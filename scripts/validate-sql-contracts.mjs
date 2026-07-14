import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const migrationDir = path.resolve('supabase/migrations');
const testFile = path.resolve('supabase/tests/phase_1_truth_layer.sql');
const errors = [];

function requireMatch(text, pattern, message) {
  if (!pattern.test(text)) errors.push(message);
}

const migrationNames = (await readdir(migrationDir))
  .filter((name) => /^20260713\d+_.*\.sql$/.test(name))
  .sort();

if (migrationNames.length !== 4) {
  errors.push(`expected 4 Phase 1 migrations, found ${migrationNames.length}`);
}

let combined = '';
for (const name of migrationNames) {
  const sql = await readFile(path.join(migrationDir, name), 'utf8');
  combined += `\n-- ${name}\n${sql}`;
  const dollarQuotes = sql.match(/\$\$/g)?.length ?? 0;
  if (dollarQuotes % 2 !== 0) errors.push(`${name} has unbalanced $$ delimiters`);
}

requireMatch(combined, /create table content\.questions\b/i, 'stable questions table is missing');
requireMatch(combined, /create table content\.question_versions\b/i, 'question versions table is missing');
requireMatch(combined, /create or replace function content\.publish_question_version\(p_version_id uuid\)/i, 'controlled publish function is missing');
requireMatch(combined, /Direct terminal\/public status transitions are prohibited/i, 'direct-publication guard is missing');
requireMatch(combined, /Child records of a published or terminal question version are immutable/i, 'published-child immutability guard is missing');
requireMatch(combined, /jsonb_contains_key_recursive/i, 'recursive answer-leak validator is missing');
requireMatch(combined, /question_reports_normalize_learner_insert/i, 'learner report normalization is missing');
requireMatch(combined, /grant usage on schema content to anon, authenticated, service_role/i, 'service role schema usage grant is missing');

const access = await readFile(path.join(migrationDir, '202607130004_truth_layer_access.sql'), 'utf8');
const learnerView = access.match(/create view content\.api_published_questions[\s\S]*?create view content\.editorial_queue/i)?.[0] ?? '';
if (!learnerView) {
  errors.push('learner-safe published question view could not be isolated');
} else {
  if (/answer_payload/i.test(learnerView)) errors.push('learner-safe view exposes answer_payload');
  if (/\bbody\b/i.test(learnerView)) errors.push('learner-safe view exposes explanation body');
}

if (/grant\s+(?:all|select|insert|update|delete)[^;]*content\.question_versions[^;]*\b(?:anon|authenticated)\b/is.test(access)) {
  errors.push('learner roles receive direct question_versions privileges');
}
if (!/grant insert \(question_version_id, reason_code, description\) on content\.question_reports to authenticated/i.test(access)) {
  errors.push('question report insert is not column-constrained');
}

const tests = await readFile(testFile, 'utf8');
const plan = Number(tests.match(/select plan\((\d+)\)/i)?.[1] ?? NaN);
const assertions = (tests.match(/^select\s+(?:has_|hasnt_|results_eq|throws_ok|is_empty|lives_ok|is\(|col_is_pk)/gim) ?? []).length;
if (!Number.isFinite(plan)) errors.push('pgTAP plan is missing');
else if (plan !== assertions) errors.push(`pgTAP plan is ${plan}, but ${assertions} assertions were found`);

requireMatch(tests, /nested answer-bearing keys fail publication validation/i, 'nested answer-leak test is missing');
requireMatch(tests, /published child rows cannot be moved to a draft version/i, 'published-child reassignment test is missing');
requireMatch(tests, /learner-safe view omits canonical answers/i, 'answer-free view test is missing');

if (errors.length) {
  console.error(`SQL contract validation failed with ${errors.length} error(s):`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`Validated ${migrationNames.length} Phase 1 migrations and ${assertions} pgTAP assertions.`);
}
