import { describe, expect, it } from "vitest";

import { runtimeFlags } from "@/lib/env";

describe("runtime flags", () => {
  it("requires an auth secret before sign-in can be treated as configured", () => {
    const previousGoogleId = process.env.GOOGLE_CLIENT_ID;
    const previousGoogleSecret = process.env.GOOGLE_CLIENT_SECRET;
    const previousNextAuthSecret = process.env.NEXTAUTH_SECRET;
    const previousAuthSecret = process.env.AUTH_SECRET;

    process.env.GOOGLE_CLIENT_ID = "google-id";
    process.env.GOOGLE_CLIENT_SECRET = "google-secret";
    delete process.env.NEXTAUTH_SECRET;
    delete process.env.AUTH_SECRET;

    expect(runtimeFlags.hasGoogleAuth()).toBe(true);
    expect(runtimeFlags.hasAuthSecret()).toBe(false);
    expect(runtimeFlags.hasPasswordAuth()).toBe(false);

    restoreEnv("GOOGLE_CLIENT_ID", previousGoogleId);
    restoreEnv("GOOGLE_CLIENT_SECRET", previousGoogleSecret);
    restoreEnv("NEXTAUTH_SECRET", previousNextAuthSecret);
    restoreEnv("AUTH_SECRET", previousAuthSecret);
  });

  it("treats password auth as configured only with a database and auth secret", () => {
    const previousDatabaseUrl = process.env.DATABASE_URL;
    const previousNextAuthSecret = process.env.NEXTAUTH_SECRET;
    const previousAuthSecret = process.env.AUTH_SECRET;

    process.env.DATABASE_URL = "postgresql://user:pass@localhost:5432/memoria";
    process.env.NEXTAUTH_SECRET = "test-secret";
    delete process.env.AUTH_SECRET;

    expect(runtimeFlags.hasPasswordAuth()).toBe(true);

    delete process.env.DATABASE_URL;
    expect(runtimeFlags.hasPasswordAuth()).toBe(false);

    restoreEnv("DATABASE_URL", previousDatabaseUrl);
    restoreEnv("NEXTAUTH_SECRET", previousNextAuthSecret);
    restoreEnv("AUTH_SECRET", previousAuthSecret);
  });
});

function restoreEnv(name: string, value: string | undefined) {
  if (value === undefined) {
    delete process.env[name];
    return;
  }

  process.env[name] = value;
}
