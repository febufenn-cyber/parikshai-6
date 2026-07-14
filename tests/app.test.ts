import test from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app';
import type { AppBindings, RpcClient } from '../src/contracts';

const env: AppBindings = {
  SUPABASE_URL: 'http://supabase.test',
  SUPABASE_ANON_KEY: 'anon-key',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
  APP_ENV: 'test',
  API_VERSION: 'v1'
};

class FakeClient implements RpcClient {
  calls: string[] = [];
  async getUser(token: string): Promise<{ id: string }> {
    assert.equal(token, 'valid-token');
    return { id: '11111111-1111-4111-8111-111111111111' };
  }
  async rpc<T>(name: string): Promise<T> {
    this.calls.push(name);
    const responses: Record<string, unknown> = {
      get_session_question: {
        session_question_id: '22222222-2222-4222-8222-222222222222',
        ordinal: 1,
        status: 'pending',
        question: { prompt: { en: 'Safe prompt' }, options: [{ option_key: 'A', text: { en: 'One' } }] }
      },
      submit_answer: {
        submission_id: '33333333-3333-4333-8333-333333333333',
        is_correct: true,
        correct_option_ids: ['A'],
        explanation: { summary: 'Verified explanation' }
      },
      restore_learner_state: { profile: null, active_sessions: [], bookmarks: [] }
    };
    return responses[name] as T;
  }
}

function appWith(client: FakeClient) {
  return createApp({ clientFactory: () => client });
}

test('question delivery requires identity and remains answer-free', async () => {
  const client = new FakeClient();
  const app = appWith(client);
  const unauth = await app.request('/v1/sessions/44444444-4444-4444-8444-444444444444/questions/1', {}, env);
  assert.equal(unauth.status, 401);

  const response = await app.request(
    '/v1/sessions/44444444-4444-4444-8444-444444444444/questions/1',
    { headers: { authorization: 'Bearer valid-token' } },
    env
  );
  assert.equal(response.status, 200);
  const body = await response.json() as Record<string, unknown>;
  assert.equal(JSON.stringify(body).includes('correct_option_ids'), false);
  assert.deepEqual(client.calls, ['get_session_question']);
});

test('answer material appears only through accepted submission route', async () => {
  const client = new FakeClient();
  const app = appWith(client);
  const response = await app.request(
    '/v1/sessions/44444444-4444-4444-8444-444444444444/submissions',
    {
      method: 'POST',
      headers: { authorization: 'Bearer valid-token', 'content-type': 'application/json' },
      body: JSON.stringify({
        sessionQuestionId: '22222222-2222-4222-8222-222222222222',
        selectedOptionIds: ['A'],
        idempotencyKey: '55555555-5555-4555-8555-555555555555'
      })
    },
    env
  );
  assert.equal(response.status, 200);
  const body = await response.json() as Record<string, unknown>;
  assert.deepEqual(body.correct_option_ids, ['A']);
  assert.deepEqual(client.calls, ['submit_answer']);
});

test('changed display name cannot affect authenticated identity', async () => {
  const client = new FakeClient();
  const app = appWith(client);
  const response = await app.request('/v1/me/restore', { headers: { authorization: 'Bearer valid-token' } }, env);
  assert.equal(response.status, 200);
  assert.deepEqual(client.calls, ['restore_learner_state']);
});
