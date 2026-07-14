import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const statusPath = path.join(root, 'docs/roadmap/phase-status.json');
const schemaPath = path.join(root, 'docs/roadmap/phase-status.schema.json');
const planPath = path.join(root, 'docs/roadmap/REMAINING_PHASES.md');

function fail(message) {
  console.error(`roadmap validation failed: ${message}`);
  process.exitCode = 1;
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    fail(`${path.relative(root, filePath)} is not valid JSON: ${error.message}`);
    return null;
  }
}

for (const filePath of [statusPath, schemaPath, planPath]) {
  assert(fs.existsSync(filePath), `${path.relative(root, filePath)} is missing`);
}

if (process.exitCode) process.exit(process.exitCode);

const status = readJson(statusPath);
const schema = readJson(schemaPath);
const plan = fs.readFileSync(planPath, 'utf8');

if (!status || !schema) process.exit(process.exitCode || 1);

assert(status.$schema === './phase-status.schema.json', 'phase-status.json must reference the local schema');
assert(status.repository === 'febufenn-cyber/parikshai-6', 'repository must be febufenn-cyber/parikshai-6');
assert(status.default_branch === 'main', 'default branch must be main');
assert(status.build_command?.required_merge_strategy === 'squash', 'phase PRs must use squash merge');

const requiredConfirmations = new Set([
  'pull_request_merged',
  'merge_commit_on_main',
  'validation_reported',
  'status_manifest_updated'
]);
const confirmations = new Set(status.build_command?.required_confirmation ?? []);
for (const item of requiredConfirmations) {
  assert(confirmations.has(item), `build confirmation is missing ${item}`);
}

assert(Array.isArray(status.phases), 'phases must be an array');
assert(status.phases.length === 6, 'roadmap must contain exactly phases 0 through 5');

const allowedStatuses = new Set(['planned', 'ready', 'in_progress', 'blocked', 'complete']);
const ids = status.phases.map((phase) => phase.id);
assert(JSON.stringify(ids) === JSON.stringify([0, 1, 2, 3, 4, 5]), 'phase IDs must be ordered 0 through 5');

const shaPattern = /^[0-9a-f]{40}$/;
let encounteredIncomplete = false;
let activeCount = 0;

for (const phase of status.phases) {
  assert(allowedStatuses.has(phase.status), `phase ${phase.id} has invalid status ${phase.status}`);
  assert(typeof phase.slug === 'string' && /^[a-z0-9-]+$/.test(phase.slug), `phase ${phase.id} has invalid slug`);
  assert(typeof phase.name === 'string' && phase.name.length > 0, `phase ${phase.id} is missing a name`);

  if (phase.status === 'complete') {
    assert(!encounteredIncomplete, `phase ${phase.id} is complete after an incomplete earlier phase`);
    assert(Number.isInteger(phase.pr) && phase.pr > 0, `complete phase ${phase.id} must record a PR number`);
    assert(typeof phase.merge_commit === 'string' && shaPattern.test(phase.merge_commit), `complete phase ${phase.id} must record a 40-character merge SHA`);
    if (phase.handoff_document) {
      assert(fs.existsSync(path.join(root, phase.handoff_document)), `phase ${phase.id} handoff document is missing`);
    }
  } else {
    encounteredIncomplete = true;
    assert(phase.pr === null, `incomplete phase ${phase.id} must not claim a merged PR`);
    assert(phase.merge_commit === null, `incomplete phase ${phase.id} must not claim a merge commit`);
  }

  if (phase.status === 'ready' || phase.status === 'in_progress' || phase.status === 'blocked') {
    activeCount += 1;
  }

  for (const dependency of phase.depends_on ?? []) {
    assert(Number.isInteger(dependency) && dependency < phase.id, `phase ${phase.id} has invalid dependency ${dependency}`);
    if (phase.status === 'ready' || phase.status === 'in_progress') {
      const dependencyPhase = status.phases.find((candidate) => candidate.id === dependency);
      assert(dependencyPhase?.status === 'complete', `phase ${phase.id} cannot be ${phase.status} until phase ${dependency} is complete`);
    }
  }

  if (phase.plan_anchor) {
    assert(plan.includes(phase.plan_anchor), `plan anchor for phase ${phase.id} is missing from REMAINING_PHASES.md`);
  }
}

const incomplete = status.phases.filter((phase) => phase.status !== 'complete');
if (incomplete.length > 0) {
  assert(activeCount === 1, 'exactly one incomplete phase must be ready, in progress, or blocked');
  const firstIncomplete = incomplete[0];
  assert(['ready', 'in_progress', 'blocked'].includes(firstIncomplete.status), 'the lowest-numbered incomplete phase must be actionable or explicitly blocked');
  for (const laterPhase of incomplete.slice(1)) {
    assert(laterPhase.status === 'planned', `later phase ${laterPhase.id} must remain planned`);
  }
} else {
  assert(activeCount === 0, 'no phase may remain active when all phases are complete');
}

assert(status.production_release_gate?.counted_as_phase === false, 'production release gate must not be counted as a phase');
assert(plan.includes(status.production_release_gate?.plan_anchor ?? ''), 'production release gate anchor is missing');
assert(plan.includes('Autonomous `build` command contract'), 'build command contract is missing');
assert(plan.includes('Branch and merge protocol'), 'branch and merge protocol is missing');
assert(plan.includes('No fabricated validation'), 'validation honesty rule is missing');

if (!process.exitCode) {
  const next = incomplete[0];
  console.log(`roadmap valid: ${incomplete.length} implementation phase(s) remain${next ? `; next is Phase ${next.id} (${next.name}) [${next.status}]` : '; implementation roadmap complete'}`);
}
