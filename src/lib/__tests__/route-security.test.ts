import { afterEach, describe, expect, it, vi } from "vitest";

const deepSeekRouteMocks = vi.hoisted(() => ({
  requireCurrentUser: vi.fn(),
  testDeepSeekConnection: vi.fn(),
}));

vi.mock("@/lib/session", () => ({
  requireCurrentUser: deepSeekRouteMocks.requireCurrentUser,
}));

vi.mock("@/lib/ai", () => ({
  DEEPSEEK_MODELS: ["deepseek-v4-flash", "deepseek-v4-pro"],
  testDeepSeekConnection: deepSeekRouteMocks.testDeepSeekConnection,
}));

describe("route security", () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  it("exposes the reminders cron handler over GET for Vercel Cron", async () => {
    const remindersCron = await import("@/app/api/cron/reminders/route");

    expect(typeof remindersCron.GET).toBe("function");
    expect(remindersCron.GET).toBe(remindersCron.POST);
  });

  it("requires an authenticated user before testing a DeepSeek key", async () => {
    deepSeekRouteMocks.requireCurrentUser.mockRejectedValueOnce(
      new Response("Unauthorized", { status: 401 }),
    );
    deepSeekRouteMocks.testDeepSeekConnection.mockResolvedValueOnce({
      model: "deepseek-v4-flash",
      service: "deepseek",
    });

    const { POST } = await import("@/app/api/deepseek/test/route");
    const response = await POST(
      new Request("https://memoria.local/api/deepseek/test", {
        method: "POST",
        body: JSON.stringify({
          apiKey: "sk-test-123456789",
          model: "deepseek-v4-flash",
          thinkingEnabled: false,
        }),
      }),
    );

    expect(response.status).toBe(401);
    expect(deepSeekRouteMocks.testDeepSeekConnection).not.toHaveBeenCalled();
  });
});
