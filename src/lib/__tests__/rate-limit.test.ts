import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  assertRateLimit,
  resetRateLimitForTests,
} from "@/lib/rate-limit";

describe("in-memory API rate limiting", () => {
  beforeEach(() => {
    resetRateLimitForTests();
    vi.useRealTimers();
  });

  it("blocks requests after the configured limit within a window", () => {
    assertRateLimit({ key: "register:127.0.0.1", limit: 2, windowMs: 60_000 });
    assertRateLimit({ key: "register:127.0.0.1", limit: 2, windowMs: 60_000 });

    try {
      assertRateLimit({ key: "register:127.0.0.1", limit: 2, windowMs: 60_000 });
      throw new Error("Expected rate limit to throw");
    } catch (error) {
      expect(error).toMatchObject({ status: 429 });
    }
  });

  it("resets a bucket after the configured window expires", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-06-15T00:00:00.000Z"));

    assertRateLimit({ key: "deepseek-test:user_1", limit: 1, windowMs: 60_000 });
    vi.setSystemTime(new Date("2026-06-15T00:01:01.000Z"));

    expect(() =>
      assertRateLimit({ key: "deepseek-test:user_1", limit: 1, windowMs: 60_000 }),
    ).not.toThrow();
  });
});
