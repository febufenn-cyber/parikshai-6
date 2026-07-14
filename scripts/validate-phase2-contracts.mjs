import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';

const errors = [];
const migrationDir = path.resolve('supabase/migrations');
const names = (await readdir(migrationDir)).filter((name) => /^20260714\d+_learning_.*\.sql$/.test(name)).sort();
if (names.length !== 6) errors.push(`expected 6 Phase 2 migrations, found ${names.length}`);

let sql = '';
for (const name of names) {
  const text = await readFile(path.join(migrationDir, name), 'utf8');
  sql += `\n${text}`;
  if ((text.match(/\$\$/g)?.length ?? 0) % 2 !== 0) errors.push(`${name} has unbalanced $$ delimiters`);
}

const requiredSql = [
  [/create table learning\.learner_profiles\b/i, 'learner profile table'],
  [/create table learning\.anonymous_identities\b/i, 'anonymous identity table'],
  [/create table learning\.practice_sessions\b/i, 'practice sessions table'],
  [/create table learning\.session_questions\b/i, 'session question snapshots'],
  [/create table learning\.answer_submissions\b/i, 'answer submissions table'],
  [/create table learning\.answer_results\b/i, 'answer results table'],
  [/create table learning\.idempotency_receipts\b/i, 'idempotency receipts'],
  [/create table learning\.evidence_events\b/i, 'append-only evidence events'],
  [/create or replace function learning\.attach_anonymous_identity/i, 'anonymous attachment workflow'],
  [/create or replace function learning\.create_practice_session/i, 'session creation workflow'],
  [/create or replace function learning\.submit_answer/i, 'atomic answer submission workflow'],
  [/create or replace function learning\.get_answer_review/i, 'post-submission review workflow'],
  [/create or replace function learning\.restore_learner_state/i, 'restore workflow'],
  [/Idempotency key conflict/i, 'idempotency conflict guard'],
  [/Answer boundary violation in session snapshot/i, 'answer boundary guard'],
  [/Append-only learner history cannot be updated or deleted/i, 'append-only history guard'],
  [/Identity migration may only reassign owner fields/i, 'narrow owner-reassignment guard'],
  [/learning\.report_context/i, 'backend report attribution context'],
  [/revoke all on all tables in schema learning from public, anon, authenticated/i, 'direct learner table access revocation'],
  [/grant execute on all functions in schema learning to service_role/i, 'backend-only function grant']
];
for (const [pattern, label] of requiredSql) if (!pattern.test(sql)) errors.push(`missing ${label}`);

const sourceFiles = [
  'src/app.ts', 'src/auth.ts', 'src/services.ts', 'src/db/supabase-rest.ts',
  'src/domain/validation.ts', 'src/env.ts', 'src/index.ts'
];
let source = '';
for (const file of sourceFiles) source += `\n${await readFile(path.resolve(file), 'utf8')}`;
const routes = [
  '/v1/identities/anonymous', '/v1/identities/attach', '/v1/me/profile', '/v1/me/restore',
  '/v1/sessions', '/questions/:ordinal', '/submissions', '/complete', '/review/:ordinal', '/v1/bookmarks/', '/v1/reports'
];
for (const route of routes) if (!source.includes(route)) errors.push(`missing API route contract ${route}`);
if (!/SUPABASE_SERVICE_ROLE_KEY/.test(source)) errors.push('service-role backend configuration is missing');
if (!/containsForbiddenAnswerKey/.test(source)) errors.push('application answer-boundary validation is missing');
if (!/idempotencyKey/.test(source)) errors.push('application idempotency contract is missing');

const testSql = await readFile(path.resolve('supabase/tests/phase_2_learning_loop.sql'), 'utf8');
const plan = Number(testSql.match(/select plan\((\d+)\)/i)?.[1] ?? NaN);
const assertions = (testSql.match(/^select\s+(?:has_|hasnt_|col_is_pk|throws_ok|lives_ok|is\(|results_eq)/gim) ?? []).length;
if (!Number.isFinite(plan) || plan !== assertions) errors.push(`Phase 2 pgTAP plan ${plan} does not match ${assertions} assertions`);

const docs = ['PHASE_2.md', 'DECISIONS.md', 'THREAT_MODEL.md', 'VALIDATION.md', 'HANDOFF.md', 'ENTRY_GATE.md'];
for (const doc of docs) {
  try { await readFile(path.resolve('docs/phase-2', doc), 'utf8'); } catch { errors.push(`missing docs/phase-2/${doc}`); }
}

if (errors.length) {
  console.error(`Phase 2 contract validation failed with ${errors.length} error(s):`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`Validated ${names.length} Phase 2 migrations, ${assertions} pgTAP assertions, API routes, and verification packet.`);
}
