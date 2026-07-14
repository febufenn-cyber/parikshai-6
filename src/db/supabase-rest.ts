import type { AppBindings, RpcClient } from '../contracts';
import { AppError } from '../http/errors';

export class SupabaseRestClient implements RpcClient {
  constructor(
    private readonly env: AppBindings,
    private readonly requestId: string,
    private readonly fetcher: typeof fetch = fetch
  ) {}

  async rpc<T>(name: string, payload: Record<string, unknown>): Promise<T> {
    const response = await this.fetcher(`${this.env.SUPABASE_URL}/rest/v1/rpc/${encodeURIComponent(name)}`, {
      method: 'POST',
      headers: {
        apikey: this.env.SUPABASE_SERVICE_ROLE_KEY,
        authorization: `Bearer ${this.env.SUPABASE_SERVICE_ROLE_KEY}`,
        'content-type': 'application/json',
        'content-profile': 'learning',
        'accept-profile': 'learning',
        'x-request-id': this.requestId
      },
      body: JSON.stringify(payload)
    });

    const body = await readBody(response);
    if (!response.ok) {
      throw new AppError(mapStatus(response.status), 'database_error', extractMessage(body), body);
    }
    return body as T;
  }

  async getUser(accessToken: string): Promise<{ id: string }> {
    const response = await this.fetcher(`${this.env.SUPABASE_URL}/auth/v1/user`, {
      headers: {
        apikey: this.env.SUPABASE_ANON_KEY,
        authorization: `Bearer ${accessToken}`,
        'x-request-id': this.requestId
      }
    });
    const body = await readBody(response);
    if (!response.ok || !body || typeof body !== 'object' || typeof (body as Record<string, unknown>).id !== 'string') {
      throw new AppError(401, 'invalid_token', 'Authentication token is invalid or expired');
    }
    const id = (body as Record<string, unknown>).id;
    if (typeof id !== 'string') throw new AppError(401, 'invalid_token', 'Authentication token is invalid or expired');
    return { id };
  }
}

async function readBody(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return null;
  try { return JSON.parse(text); } catch { return text; }
}

function extractMessage(body: unknown): string {
  if (body && typeof body === 'object') {
    const record = body as Record<string, unknown>;
    for (const key of ['message', 'details', 'hint']) {
      if (typeof record[key] === 'string' && record[key]) return record[key];
    }
  }
  return 'Database request failed';
}

function mapStatus(status: number): number {
  if (status === 401 || status === 403) return status;
  if (status === 404) return 404;
  if (status === 409) return 409;
  if (status >= 400 && status < 500) return 400;
  return 503;
}
