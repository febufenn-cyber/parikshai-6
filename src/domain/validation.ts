import { AppError } from '../http/errors';
import type { CreateSessionInput, LearnerProfileInput, SubmitAnswerInput } from '../contracts';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const LANGUAGE = /^[a-z]{2,3}(?:-[A-Z]{2})?$/;
const STABLE_ID = /^[a-z0-9][a-z0-9_.:-]{1,127}$/;
const FORBIDDEN_KEYS = /^(answer|answers|answer_key|correct|correct_answer|correct_option_ids|rationale|explanation|explanation_body)$/i;

export function requireUuid(value: unknown, field: string): string {
  if (typeof value !== 'string' || !UUID.test(value)) {
    throw new AppError(400, 'invalid_request', `${field} must be a UUID`);
  }
  return value;
}

export function requireStableId(value: unknown, field: string): string {
  if (typeof value !== 'string' || !STABLE_ID.test(value)) {
    throw new AppError(400, 'invalid_request', `${field} must be a stable lowercase identifier`);
  }
  return value;
}

export function requireLanguage(value: unknown): string {
  if (typeof value !== 'string' || !LANGUAGE.test(value)) {
    throw new AppError(400, 'invalid_request', 'language must be a BCP-47 language code');
  }
  return value;
}

export function parseCreateSession(value: unknown): CreateSessionInput {
  if (!value || typeof value !== 'object') throw new AppError(400, 'invalid_request', 'JSON body required');
  const body = value as Record<string, unknown>;
  const kind = body.kind;
  if (kind !== 'diagnostic' && kind !== 'daily' && kind !== 'topic') {
    throw new AppError(400, 'invalid_request', 'kind must be diagnostic, daily, or topic');
  }
  const questionCount = Number(body.questionCount);
  if (!Number.isInteger(questionCount) || questionCount < 1 || questionCount > 50) {
    throw new AppError(400, 'invalid_request', 'questionCount must be an integer from 1 to 50');
  }
  const topicNodeId = body.topicNodeId;
  if (kind === 'topic' && (typeof topicNodeId !== 'string' || topicNodeId.length === 0)) {
    throw new AppError(400, 'invalid_request', 'topicNodeId is required for topic sessions');
  }
  return {
    kind,
    examId: requireStableId(body.examId, 'examId'),
    ...(typeof topicNodeId === 'string' ? { topicNodeId } : {}),
    language: requireLanguage(body.language),
    questionCount,
    clientSessionKey: requireUuid(body.clientSessionKey, 'clientSessionKey')
  };
}

export function parseSubmitAnswer(value: unknown): SubmitAnswerInput {
  if (!value || typeof value !== 'object') throw new AppError(400, 'invalid_request', 'JSON body required');
  const body = value as Record<string, unknown>;
  if (!Array.isArray(body.selectedOptionIds) || body.selectedOptionIds.some((id) => typeof id !== 'string')) {
    throw new AppError(400, 'invalid_request', 'selectedOptionIds must be an array of strings');
  }
  const normalized = [...new Set(body.selectedOptionIds)].sort();
  if (normalized.length === 0) throw new AppError(400, 'invalid_request', 'at least one option must be selected');
  const elapsed = body.elapsedMs === undefined ? undefined : Number(body.elapsedMs);
  if (elapsed !== undefined && (!Number.isInteger(elapsed) || elapsed < 0 || elapsed > 86_400_000)) {
    throw new AppError(400, 'invalid_request', 'elapsedMs is out of range');
  }
  return {
    sessionQuestionId: requireUuid(body.sessionQuestionId, 'sessionQuestionId'),
    selectedOptionIds: normalized,
    ...(body.responsePayload && typeof body.responsePayload === 'object' ? { responsePayload: body.responsePayload as Record<string, unknown> } : {}),
    ...(elapsed === undefined ? {} : { elapsedMs: elapsed }),
    ...(typeof body.clientSubmittedAt === 'string' ? { clientSubmittedAt: body.clientSubmittedAt } : {}),
    idempotencyKey: requireUuid(body.idempotencyKey, 'idempotencyKey')
  };
}

export function parseProfile(value: unknown): LearnerProfileInput {
  if (!value || typeof value !== 'object') throw new AppError(400, 'invalid_request', 'JSON body required');
  const body = value as Record<string, unknown>;
  return {
    ...(typeof body.displayName === 'string' ? { displayName: body.displayName.trim().slice(0, 120) } : {}),
    preferredLanguage: requireLanguage(body.preferredLanguage),
    ...(body.examId === undefined ? {} : { examId: requireStableId(body.examId, 'examId') }),
    ...(body.onboarding && typeof body.onboarding === 'object' ? { onboarding: body.onboarding as Record<string, unknown> } : {})
  };
}

export function containsForbiddenAnswerKey(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(containsForbiddenAnswerKey);
  if (!value || typeof value !== 'object') return false;
  for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
    if (FORBIDDEN_KEYS.test(key)) return true;
    if (containsForbiddenAnswerKey(nested)) return true;
  }
  return false;
}
