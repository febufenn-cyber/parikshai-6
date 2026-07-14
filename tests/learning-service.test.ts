import test from 'node:test';
import assert from 'node:assert/strict';
import { LearningService } from '../src/services';
import type { RpcClient } from '../src/contracts';

class FakeClient implements RpcClient {
  calls: Array<{ name: string; payload: Record<string, unknown> }> = [];
  constructor(private readonly responses: Record<string, unknown> = {}) {}
  async rpc<T>(name: string, payload: Record<string, unknown>): Promise<T> {
    this.calls.push({ name, payload });
    return this.responses[name] as T;
  }
  async getUser(): Promise<{ id: string }> { return { id: '11111111-1111-4111-8111-111111111111' }; }
}

test('anonymous identity secret is generated server-side and sent only to hash RPC', async () => {
  const client = new FakeClient({ create_anonymous_identity: { anonymous_id: '22222222-2222-4222-8222-222222222222' } });
  const service = new LearningService(client);
  const identity = await service.createAnonymousIdentity();
  assert.equal(identity.anonymousId, '22222222-2222-4222-8222-222222222222');
  assert.ok(identity.secret.length >= 40);
  assert.equal(client.calls[0]?.name, 'create_anonymous_identity');
  assert.equal(client.calls[0]?.payload.p_secret, identity.secret);
});

test('pre-submission question rejects deeply nested answer material', async () => {
  const client = new FakeClient({
    get_session_question: { question: { shared: { metadata: { correct_option_ids: ['A'] } } } }
  });
  const service = new LearningService(client);
  await assert.rejects(
    () => service.getQuestion({ kind: 'authenticated', userId: '11111111-1111-4111-8111-111111111111' }, '33333333-3333-4333-8333-333333333333', 1),
    /forbidden answer material/
  );
});

test('submission normalizes identity into backend-only RPC fields', async () => {
  const client = new FakeClient({ submit_answer: { submission_id: 'ok', is_correct: true } });
  const service = new LearningService(client);
  await service.submit(
    { kind: 'anonymous', anonymousId: '44444444-4444-4444-8444-444444444444', secret: 's'.repeat(40) },
    '55555555-5555-4555-8555-555555555555',
    {
      sessionQuestionId: '66666666-6666-4666-8666-666666666666',
      selectedOptionIds: ['A'],
      idempotencyKey: '77777777-7777-4777-8777-777777777777'
    }
  );
  assert.equal(client.calls[0]?.payload.p_user_id, null);
  assert.equal(client.calls[0]?.payload.p_anonymous_id, '44444444-4444-4444-8444-444444444444');
  assert.equal(client.calls[0]?.payload.p_idempotency_key, '77777777-7777-4777-8777-777777777777');
});
