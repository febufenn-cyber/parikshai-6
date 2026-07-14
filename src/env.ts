import type { AppBindings } from './contracts';

const REQUIRED_KEYS: Array<keyof AppBindings> = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'SUPABASE_SERVICE_ROLE_KEY'
];

export function validateEnv(env: AppBindings): AppBindings {
  const missing = REQUIRED_KEYS.filter((key) => !env[key]?.trim());
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  let parsed: URL;
  try {
    parsed = new URL(env.SUPABASE_URL);
  } catch {
    throw new Error('SUPABASE_URL must be a valid absolute URL');
  }

  if (parsed.protocol !== 'https:' && env.APP_ENV !== 'test') {
    throw new Error('SUPABASE_URL must use HTTPS outside tests');
  }

  return env;
}
