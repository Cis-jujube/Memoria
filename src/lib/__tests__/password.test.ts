import { describe, expect, it } from "vitest";

import {
  hashPassword,
  isValidPassword,
  normalizeEmail,
  verifyPassword,
} from "@/lib/password";

describe("password auth helpers", () => {
  it("normalizes account emails before lookup", () => {
    expect(normalizeEmail("  Ethan@Example.COM ")).toBe("ethan@example.com");
  });

  it("hashes passwords without storing the raw password", () => {
    const hash = hashPassword("correct-horse-battery");

    expect(hash).toContain("pbkdf2_sha256");
    expect(hash).not.toContain("correct-horse-battery");
    expect(verifyPassword("correct-horse-battery", hash)).toBe(true);
    expect(verifyPassword("wrong-password", hash)).toBe(false);
  });

  it("requires at least eight password characters", () => {
    expect(isValidPassword("1234567")).toBe(false);
    expect(isValidPassword("12345678")).toBe(true);
  });
});
