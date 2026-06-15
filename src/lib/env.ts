export function hasEnv(name: string) {
  return Boolean(process.env[name] && process.env[name]?.trim());
}

export function getEnv(name: string, fallback = "") {
  return process.env[name]?.trim() || fallback;
}

export function requireEnv(name: string) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is not configured`);
  }
  return value;
}

export const runtimeFlags = {
  hasOpenAiKey: () => hasEnv("OPENAI_API_KEY"),
  hasDeepSeekKey: () => hasEnv("DEEPSEEK_API_KEY"),
  hasBlobToken: () => hasEnv("BLOB_READ_WRITE_TOKEN"),
  hasSendGridKey: () => hasEnv("SENDGRID_API_KEY"),
  hasAuthSecret: () => hasEnv("NEXTAUTH_SECRET") || hasEnv("AUTH_SECRET"),
  hasDatabaseUrl: () => hasEnv("DATABASE_URL"),
  hasGoogleAuth: () =>
    hasEnv("GOOGLE_CLIENT_ID") && hasEnv("GOOGLE_CLIENT_SECRET"),
  hasPasswordAuth: () =>
    runtimeFlags.hasAuthSecret() && runtimeFlags.hasDatabaseUrl(),
};
