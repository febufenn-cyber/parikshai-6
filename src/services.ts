import type {
  CreateSessionInput,
  LearnerIdentity,
  LearnerProfileInput,
  RpcClient,
  SubmitAnswerInput
} from './contracts';
import { AppError } from './http/errors';
import { containsForbiddenAnswerKey } from './domain/validation';

export class LearningService {
  constructor(private readonly db: RpcClient) {}

  async createAnonymousIdentity(): Promise<{ anonymousId: string; secret: string }> {
    const secret = randomSecret();
    const result = await this.db.rpc<{ anonymous_id: string }>('create_anonymous_identity', { p_secret: secret });
    if (!result?.anonymous_id) throw new AppError(503, 'identity_creation_failed', 'Anonymous identity was not created');
    return { anonymousId: result.anonymous_id, secret };
  }

  attachAnonymous(userId: string, anonymousId: string, secret: string, idempotencyKey: string): Promise<unknown> {
    return this.db.rpc('attach_anonymous_identity', {
      p_user_id: userId,
      p_anonymous_id: anonymousId,
      p_secret: secret,
      p_idempotency_key: idempotencyKey
    });
  }

  upsertProfile(userId: string, profile: LearnerProfileInput): Promise<unknown> {
    return this.db.rpc('upsert_learner_profile', {
      p_user_id: userId,
      p_display_name: profile.displayName ?? null,
      p_preferred_language: profile.preferredLanguage,
      p_exam_id: profile.examId ?? null,
      p_onboarding: profile.onboarding ?? {}
    });
  }

  createSession(identity: LearnerIdentity, input: CreateSessionInput): Promise<unknown> {
    return this.db.rpc('create_practice_session', {
      ...identityPayload(identity),
      p_kind: input.kind,
      p_exam_id: input.examId,
      p_topic_node_id: input.topicNodeId ?? null,
      p_language: input.language,
      p_question_count: input.questionCount,
      p_client_session_key: input.clientSessionKey
    });
  }

  getSession(identity: LearnerIdentity, sessionId: string): Promise<unknown> {
    return this.db.rpc('get_session_snapshot', { ...identityPayload(identity), p_session_id: sessionId });
  }

  async getQuestion(identity: LearnerIdentity, sessionId: string, ordinal: number): Promise<unknown> {
    const result = await this.db.rpc<unknown>('get_session_question', {
      ...identityPayload(identity), p_session_id: sessionId, p_ordinal: ordinal
    });
    if (containsForbiddenAnswerKey(result)) {
      throw new AppError(500, 'answer_boundary_violation', 'Pre-submission payload contains forbidden answer material');
    }
    return result;
  }

  submit(identity: LearnerIdentity, sessionId: string, input: SubmitAnswerInput): Promise<unknown> {
    return this.db.rpc('submit_answer', {
      ...identityPayload(identity),
      p_session_id: sessionId,
      p_session_question_id: input.sessionQuestionId,
      p_selected_option_ids: input.selectedOptionIds,
      p_response_payload: input.responsePayload ?? {},
      p_elapsed_ms: input.elapsedMs ?? null,
      p_client_submitted_at: input.clientSubmittedAt ?? null,
      p_idempotency_key: input.idempotencyKey
    });
  }

  completeSession(identity: LearnerIdentity, sessionId: string, idempotencyKey: string): Promise<unknown> {
    return this.db.rpc('complete_practice_session', {
      ...identityPayload(identity), p_session_id: sessionId, p_idempotency_key: idempotencyKey
    });
  }

  getReview(identity: LearnerIdentity, sessionId: string, ordinal: number): Promise<unknown> {
    return this.db.rpc('get_answer_review', {
      ...identityPayload(identity), p_session_id: sessionId, p_ordinal: ordinal
    });
  }

  restore(identity: LearnerIdentity): Promise<unknown> {
    return this.db.rpc('restore_learner_state', identityPayload(identity));
  }

  setBookmark(identity: LearnerIdentity, questionVersionId: string, active: boolean): Promise<unknown> {
    return this.db.rpc('set_bookmark', {
      ...identityPayload(identity), p_question_version_id: questionVersionId, p_active: active
    });
  }

  report(identity: LearnerIdentity, questionVersionId: string, reasonCode: string, description?: string): Promise<unknown> {
    if (!/^[a-z0-9_]{2,64}$/.test(reasonCode)) {
      throw new AppError(400, 'invalid_request', 'reasonCode is invalid');
    }
    return this.db.rpc('report_question', {
      ...identityPayload(identity),
      p_question_version_id: questionVersionId,
      p_reason_code: reasonCode,
      p_description: description?.slice(0, 2000) ?? null
    });
  }
}

function identityPayload(identity: LearnerIdentity): Record<string, unknown> {
  return identity.kind === 'authenticated'
    ? { p_user_id: identity.userId, p_anonymous_id: null, p_anonymous_secret: null }
    : { p_user_id: null, p_anonymous_id: identity.anonymousId, p_anonymous_secret: identity.secret };
}

function randomSecret(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}
