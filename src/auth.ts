import type { LearnerIdentity, RpcClient } from './contracts';
import { AppError } from './http/errors';
import { requireUuid } from './domain/validation';

export async function resolveIdentity(request: Request, client: RpcClient): Promise<LearnerIdentity> {
  const authorization = request.headers.get('authorization');
  if (authorization?.startsWith('Bearer ')) {
    const token = authorization.slice('Bearer '.length).trim();
    if (!token) throw new AppError(401, 'invalid_token', 'Bearer token is empty');
    const user = await client.getUser(token);
    return { kind: 'authenticated', userId: user.id };
  }

  const anonymousId = request.headers.get('x-anonymous-id');
  const secret = request.headers.get('x-anonymous-secret');
  if (anonymousId && secret) {
    if (secret.length < 32 || secret.length > 256) {
      throw new AppError(401, 'invalid_anonymous_secret', 'Anonymous secret is invalid');
    }
    return { kind: 'anonymous', anonymousId: requireUuid(anonymousId, 'x-anonymous-id'), secret };
  }

  throw new AppError(401, 'authentication_required', 'Bearer token or anonymous credentials required');
}

export function requireAuthenticated(identity: LearnerIdentity): string {
  if (identity.kind !== 'authenticated') {
    throw new AppError(401, 'authentication_required', 'Authenticated account required');
  }
  return identity.userId;
}
