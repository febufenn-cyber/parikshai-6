export type SessionKind = 'diagnostic' | 'daily' | 'topic';

export type AuthenticatedIdentity = {
  kind: 'authenticated';
  userId: string;
};

export type AnonymousIdentity = {
  kind: 'anonymous';
  anonymousId: string;
  secret: string;
};

export type LearnerIdentity = AuthenticatedIdentity | AnonymousIdentity;

export type CreateSessionInput = {
  kind: SessionKind;
  examId: string;
  topicNodeId?: string;
  language: string;
  questionCount: number;
  clientSessionKey: string;
};

export type SubmitAnswerInput = {
  sessionQuestionId: string;
  selectedOptionIds: string[];
  responsePayload?: Record<string, unknown>;
  elapsedMs?: number;
  clientSubmittedAt?: string;
  idempotencyKey: string;
};

export type LearnerProfileInput = {
  displayName?: string;
  preferredLanguage: string;
  examId?: string;
  onboarding?: Record<string, unknown>;
};

export type RpcClient = {
  rpc<T>(name: string, payload: Record<string, unknown>): Promise<T>;
  getUser(accessToken: string): Promise<{ id: string }>;
};

export type AppBindings = {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  APP_ENV?: string;
  API_VERSION?: string;
};
