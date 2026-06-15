import { publicApiError } from "@/lib/api";

type RateLimitBucket = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, RateLimitBucket>();

export function assertRateLimit({
  key,
  limit,
  windowMs,
}: {
  key: string;
  limit: number;
  windowMs: number;
}) {
  const now = Date.now();
  const bucket = buckets.get(key);

  if (!bucket || bucket.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return;
  }

  if (bucket.count >= limit) {
    throw publicApiError("Too many requests. Please try again later.", 429);
  }

  bucket.count += 1;
}

export function assertRequestRateLimit({
  request,
  scope,
  limit,
  windowMs,
  userId,
}: {
  request: Request;
  scope: string;
  limit: number;
  windowMs: number;
  userId?: string;
}) {
  assertRateLimit({
    key: `${scope}:${userId || getClientIp(request)}`,
    limit,
    windowMs,
  });
}

export function getClientIp(request: Request) {
  const forwardedFor = request.headers.get("x-forwarded-for");
  const forwardedIp = forwardedFor?.split(",")[0]?.trim();

  return forwardedIp || request.headers.get("x-real-ip")?.trim() || "unknown";
}

export function resetRateLimitForTests() {
  buckets.clear();
}
