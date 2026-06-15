import { describe, expect, it } from "vitest";

import nextConfig from "../../../next.config";

describe("Next.js security headers", () => {
  it("sets baseline browser security headers on all routes", async () => {
    const headerRules = await nextConfig.headers?.();
    const globalRule = headerRules?.find((rule) => rule.source === "/:path*");
    const headers = Object.fromEntries(
      (globalRule?.headers || []).map((header) => [
        header.key.toLowerCase(),
        header.value,
      ]),
    );

    expect(headers["content-security-policy"]).toContain("frame-ancestors 'none'");
    expect(headers["x-frame-options"]).toBe("DENY");
    expect(headers["x-content-type-options"]).toBe("nosniff");
    expect(headers["referrer-policy"]).toBe("strict-origin-when-cross-origin");
    expect(headers["permissions-policy"]).toContain("camera=()");
  });
});
