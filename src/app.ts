import { Hono } from 'hono';
import type { AppBindings, RpcClient } from './contracts';
import { validateEnv } from './env';
import { SupabaseRestClient } from './db/supabase-rest';
import { LearningService } from './services';
import { resolveIdentity, requireAuthenticated } from './auth';
import { asAppError, AppError } from './http/errors';
import { parseCreateSession, parseProfile, parseSubmitAnswer, requireUuid } from './domain/validation';

type Variables = {
  requestId: string;
  db: RpcClient;
  service: LearningService;
};

type AppEnv = { Bindings: AppBindings; Variables: Variables };

type Dependencies = {
  clientFactory?: (env: AppBindings, requestId: string) => RpcClient;
};

export function createApp(dependencies: Dependencies = {}) {
  const app = new Hono<AppEnv>();

  app.use('*', async (c, next) => {
    const requestId = c.req.header('x-request-id') || crypto.randomUUID();
    c.set('requestId', requestId);
    c.header('x-request-id', requestId);
    await next();
  });

  app.use('/v1/*', async (c, next) => {
    const env = validateEnv(c.env);
    const db = dependencies.clientFactory?.(env, c.get('requestId')) ?? new SupabaseRestClient(env, c.get('requestId'));
    c.set('db', db);
    c.set('service', new LearningService(db));
    await next();
  });

  app.onError((error, c) => {
    const appError = asAppError(error);
    return c.json({
      error: { code: appError.code, message: appError.message, ...(appError.details === undefined ? {} : { details: appError.details }) },
      requestId: c.get('requestId')
    }, appError.status as 400 | 401 | 403 | 404 | 409 | 500 | 503);
  });

  app.get('/healthz', (c) => c.json({ status: 'ok' }));
  app.get('/readyz', (c) => {
    validateEnv(c.env);
    return c.json({ status: 'ready', phase: 2 });
  });

  app.post('/v1/identities/anonymous', async (c) => c.json(await c.get('service').createAnonymousIdentity(), 201));

  app.post('/v1/identities/attach', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    const userId = requireAuthenticated(identity);
    const body = await jsonBody(c.req.raw);
    const anonymousId = requireUuid(body.anonymousId, 'anonymousId');
    const secret = typeof body.secret === 'string' ? body.secret : '';
    if (secret.length < 32) throw new AppError(400, 'invalid_request', 'secret is invalid');
    const idempotencyKey = requireUuid(body.idempotencyKey, 'idempotencyKey');
    return c.json(await c.get('service').attachAnonymous(userId, anonymousId, secret, idempotencyKey));
  });

  app.put('/v1/me/profile', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    const userId = requireAuthenticated(identity);
    return c.json(await c.get('service').upsertProfile(userId, parseProfile(await c.req.json())));
  });

  app.get('/v1/me/restore', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    return c.json(await c.get('service').restore(identity));
  });

  app.post('/v1/sessions', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    return c.json(await c.get('service').createSession(identity, parseCreateSession(await c.req.json())), 201);
  });

  app.get('/v1/sessions/:sessionId', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    return c.json(await c.get('service').getSession(identity, requireUuid(c.req.param('sessionId'), 'sessionId')));
  });

  app.get('/v1/sessions/:sessionId/questions/:ordinal', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    const ordinal = Number(c.req.param('ordinal'));
    if (!Number.isInteger(ordinal) || ordinal < 1) throw new AppError(400, 'invalid_request', 'ordinal must be a positive integer');
    return c.json(await c.get('service').getQuestion(identity, requireUuid(c.req.param('sessionId'), 'sessionId'), ordinal));
  });

  app.post('/v1/sessions/:sessionId/submissions', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    return c.json(await c.get('service').submit(
      identity,
      requireUuid(c.req.param('sessionId'), 'sessionId'),
      parseSubmitAnswer(await c.req.json())
    ));
  });

  app.post('/v1/sessions/:sessionId/complete', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    const body = await jsonBody(c.req.raw);
    return c.json(await c.get('service').completeSession(
      identity,
      requireUuid(c.req.param('sessionId'), 'sessionId'),
      requireUuid(body.idempotencyKey, 'idempotencyKey')
    ));
  });

  app.get('/v1/sessions/:sessionId/review/:ordinal', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    const ordinal = Number(c.req.param('ordinal'));
    if (!Number.isInteger(ordinal) || ordinal < 1) throw new AppError(400, 'invalid_request', 'ordinal must be a positive integer');
    return c.json(await c.get('service').getReview(identity, requireUuid(c.req.param('sessionId'), 'sessionId'), ordinal));
  });

  app.put('/v1/bookmarks/:questionVersionId', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    return c.json(await c.get('service').setBookmark(identity, requireUuid(c.req.param('questionVersionId'), 'questionVersionId'), true));
  });

  app.delete('/v1/bookmarks/:questionVersionId', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    return c.json(await c.get('service').setBookmark(identity, requireUuid(c.req.param('questionVersionId'), 'questionVersionId'), false));
  });

  app.post('/v1/reports', async (c) => {
    const identity = await resolveIdentity(c.req.raw, c.get('db'));
    const body = await jsonBody(c.req.raw);
    return c.json(await c.get('service').report(
      identity,
      requireUuid(body.questionVersionId, 'questionVersionId'),
      typeof body.reasonCode === 'string' ? body.reasonCode : '',
      typeof body.description === 'string' ? body.description : undefined
    ), 201);
  });

  app.notFound((c) => c.json({ error: { code: 'not_found', message: 'Route not found' }, requestId: c.get('requestId') }, 404));
  return app;
}

async function jsonBody(request: Request): Promise<Record<string, unknown>> {
  try {
    const value = await request.json();
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error();
    return value as Record<string, unknown>;
  } catch {
    throw new AppError(400, 'invalid_request', 'Valid JSON object required');
  }
}
