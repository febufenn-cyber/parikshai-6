import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const ROOT = path.resolve('fixtures/launch-question-sample');
const VALID_CLASSES = new Set(['official', 'curated', 'ai_assisted', 'experimental']);
const VALID_STATUSES = new Set([
  'imported',
  'structurally_valid',
  'answer_verified',
  'explanation_verified',
  'language_reviewed',
  'publishable',
  'published',
  'disputed',
  'corrected',
  'archived'
]);
const SCORABLE_STATUSES = new Set(['publishable', 'published', 'disputed', 'corrected']);
const CHOICE_TYPES = new Set([
  'direct_mcq',
  'multi_statement',
  'assertion_reason',
  'match',
  'passage_linked',
  'table_data',
  'chronology',
  'image_diagram',
  'multi_select'
]);

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function localizedText(value, field, errors) {
  if (!isObject(value) || Object.keys(value).length === 0) {
    errors.push(`${field} must be a non-empty localized object`);
    return;
  }
  for (const [language, text] of Object.entries(value)) {
    if (!/^[a-z]{2,3}(?:-[A-Z]{2})?$/.test(language)) {
      errors.push(`${field} has invalid language key: ${language}`);
    }
    if (typeof text !== 'string' || text.trim().length === 0) {
      errors.push(`${field}.${language} must be non-empty text`);
    }
  }
}

function validateFixture(fixture, filename) {
  const errors = [];
  const required = [
    'question_id', 'version_id', 'content_class', 'status', 'exam', 'syllabus',
    'type', 'prompt', 'options', 'answer', 'provenance', 'language'
  ];

  for (const field of required) {
    if (!(field in fixture)) errors.push(`missing required field: ${field}`);
  }

  if (!/^q_[a-z0-9_]+$/.test(fixture.question_id ?? '')) {
    errors.push('question_id must match ^q_[a-z0-9_]+$');
  }
  if (!/^qv_[a-z0-9_]+$/.test(fixture.version_id ?? '')) {
    errors.push('version_id must match ^qv_[a-z0-9_]+$');
  }
  if (!VALID_CLASSES.has(fixture.content_class)) {
    errors.push(`invalid content_class: ${fixture.content_class}`);
  }
  if (!VALID_STATUSES.has(fixture.status)) {
    errors.push(`invalid status: ${fixture.status}`);
  }

  localizedText(fixture.prompt, 'prompt', errors);

  if (!isObject(fixture.exam) || !fixture.exam.exam_id || !fixture.exam.syllabus_version) {
    errors.push('exam must contain exam_id and syllabus_version');
  }
  if (!isObject(fixture.syllabus) || !fixture.syllabus.primary_node_id) {
    errors.push('syllabus must contain primary_node_id');
  }
  if (!isObject(fixture.language) || !fixture.language.original || !Array.isArray(fixture.language.available)) {
    errors.push('language must contain original and available[]');
  } else if (!fixture.language.available.includes(fixture.language.original)) {
    errors.push('language.available must contain language.original');
  }

  if (!Array.isArray(fixture.options)) {
    errors.push('options must be an array');
  } else {
    if (CHOICE_TYPES.has(fixture.type) && fixture.options.length < 2) {
      errors.push(`${fixture.type} requires at least two options`);
    }
    const keys = new Set();
    for (const [index, option] of fixture.options.entries()) {
      if (!isObject(option) || typeof option.option_id !== 'string' || !option.option_id) {
        errors.push(`options[${index}].option_id must be non-empty`);
        continue;
      }
      if (keys.has(option.option_id)) errors.push(`duplicate option_id: ${option.option_id}`);
      keys.add(option.option_id);
      localizedText(option.text, `options[${index}].text`, errors);
    }

    const correct = fixture.answer?.correct_option_ids;
    if (!Array.isArray(correct) || correct.length === 0) {
      errors.push('answer.correct_option_ids must be a non-empty array');
    } else {
      for (const key of correct) {
        if (!keys.has(key)) errors.push(`correct option does not exist: ${key}`);
      }
      if (fixture.type !== 'multi_select' && correct.length > 1) {
        errors.push(`${fixture.type} cannot declare multiple correct options`);
      }
    }
  }

  if (!isObject(fixture.provenance) || !fixture.provenance.source_type || !fixture.provenance.source_id) {
    errors.push('provenance must contain source_type and source_id');
  }

  const verified = fixture.answer?.verified === true;
  if (fixture.content_class === 'experimental') {
    if (verified) errors.push('experimental content cannot have answer.verified=true');
    if (SCORABLE_STATUSES.has(fixture.status)) {
      errors.push(`experimental content cannot use scorable status: ${fixture.status}`);
    }
  }
  if (SCORABLE_STATUSES.has(fixture.status) && !verified) {
    errors.push(`${fixture.status} content requires answer.verified=true`);
  }
  if (fixture.status === 'published' && !fixture.review?.reviewer_id) {
    errors.push('published content requires review.reviewer_id');
  }

  return errors.map((message) => `${filename}: ${message}`);
}

async function main() {
  const files = (await readdir(ROOT))
    .filter((name) => name.endsWith('.json') && !name.endsWith('.schema.json'))
    .sort();

  if (files.length === 0) {
    throw new Error(`No fixture JSON files found in ${ROOT}`);
  }

  const errors = [];
  for (const filename of files) {
    const raw = await readFile(path.join(ROOT, filename), 'utf8');
    let fixture;
    try {
      fixture = JSON.parse(raw);
    } catch (error) {
      errors.push(`${filename}: invalid JSON (${error.message})`);
      continue;
    }
    errors.push(...validateFixture(fixture, filename));
  }

  if (errors.length > 0) {
    console.error(`Fixture validation failed with ${errors.length} error(s):`);
    for (const error of errors) console.error(`- ${error}`);
    process.exitCode = 1;
    return;
  }

  console.log(`Validated ${files.length} question fixture(s).`);
}

main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exitCode = 1;
});
