import { describe, expect, it } from "vitest";

import {
  buildDeepSeekChatRequest,
  MAX_PENDING_UPDATES_PER_CAPTURE,
  normalizeExtractionToPendingUpdates,
  parseExtractionPayload,
  resolveAIProvider,
  stringifyChatMessageContent,
} from "@/lib/ai";

describe("AI extraction normalization", () => {
  it("parses a structured extraction payload and turns facts into user-scoped pending updates", () => {
    const payload = parseExtractionPayload({
      people: [
        {
          displayName: " Alex Chen ",
          relationLabel: "classmate",
          updates: [
            {
              type: "PREFERENCE",
              fieldPath: "preferences.food",
              proposedValue: ["hotpot", "matcha"],
              summary: "Alex likes hotpot and matcha.",
              evidence: "Alex said he wants hotpot after finals.",
              confidence: 0.93,
            },
          ],
        },
      ],
      reminders: [
        {
          personName: "Alex Chen",
          title: "Ask about calculus midterm",
          dueAt: "2026-05-20T12:00:00.000Z",
          evidence: "He has a calculus midterm on 5/20.",
          confidence: 0.8,
        },
      ],
      giftIdeas: [
        {
          personName: "Alex Chen",
          title: "Matcha sampler",
          rationale: "He likes matcha.",
          priceBand: "$",
          sourceFacts: ["likes matcha"],
        },
      ],
    });

    const pending = normalizeExtractionToPendingUpdates({
      userId: "user_1",
      sourceId: "memory_1",
      sourceType: "natural_language",
      extraction: payload,
    });

    expect(pending).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          userId: "user_1",
          personName: "Alex Chen",
          type: "PREFERENCE",
          fieldPath: "preferences.food",
          confidence: 0.93,
          sourceId: "memory_1",
        }),
        expect.objectContaining({
          userId: "user_1",
          personName: "Alex Chen",
          type: "REMINDER",
          fieldPath: "reminders",
          summary: "Ask about calculus midterm",
        }),
        expect.objectContaining({
          userId: "user_1",
          personName: "Alex Chen",
          type: "GIFT_IDEA",
          fieldPath: "giftIdeas",
          summary: "Matcha sampler",
        }),
      ]),
    );
  });

  it("caps AI-generated pending updates from a single capture", () => {
    const payload = parseExtractionPayload({
      people: Array.from({ length: MAX_PENDING_UPDATES_PER_CAPTURE + 8 }, (_, index) => ({
        displayName: `Person ${index + 1}`,
        relationLabel: "friend",
        updates: [
          {
            type: "PREFERENCE",
            fieldPath: "preferences.favoriteFoods",
            proposedValue: [`food-${index + 1}`],
            summary: `Person ${index + 1} likes food-${index + 1}.`,
            evidence: `The note mentioned food-${index + 1}.`,
            confidence: 0.8,
          },
        ],
      })),
      reminders: [],
      giftIdeas: [],
    });

    const pending = normalizeExtractionToPendingUpdates({
      userId: "user_1",
      sourceId: "memory_1",
      sourceType: "natural_language",
      extraction: payload,
    });

    expect(pending).toHaveLength(MAX_PENDING_UPDATES_PER_CAPTURE);
    expect(pending.at(-1)?.personName).toBe(`Person ${MAX_PENDING_UPDATES_PER_CAPTURE}`);
  });

  it("rejects malformed extraction payloads instead of accepting arbitrary JSON", () => {
    expect(() =>
      parseExtractionPayload({
        people: [{ displayName: "", updates: [] }],
        reminders: [],
        giftIdeas: [],
      }),
    ).toThrow();
  });

  it("chooses DeepSeek when explicitly configured", () => {
    const previousProvider = process.env.AI_PROVIDER;

    process.env.AI_PROVIDER = "deepseek";

    expect(resolveAIProvider()).toBe("deepseek");

    restoreEnv("AI_PROVIDER", previousProvider);
  });

  it("falls back to DeepSeek when only DeepSeek has a key", () => {
    const previousProvider = process.env.AI_PROVIDER;
    const previousOpenAIKey = process.env.OPENAI_API_KEY;
    const previousDeepSeekKey = process.env.DEEPSEEK_API_KEY;

    delete process.env.AI_PROVIDER;
    delete process.env.OPENAI_API_KEY;
    process.env.DEEPSEEK_API_KEY = "test-key";

    expect(resolveAIProvider()).toBe("deepseek");

    restoreEnv("AI_PROVIDER", previousProvider);
    restoreEnv("OPENAI_API_KEY", previousOpenAIKey);
    restoreEnv("DEEPSEEK_API_KEY", previousDeepSeekKey);
  });

  it("normalizes DeepSeek-compatible message content", () => {
    expect(stringifyChatMessageContent("plain json")).toBe("plain json");
    expect(
      stringifyChatMessageContent([
        { type: "text", text: "{\"people\":" },
        { type: "text", text: "[]}" },
      ]),
    ).toBe("{\"people\":[]}");
    expect(stringifyChatMessageContent(null)).toBe("");
  });

  it("builds DeepSeek chat requests with model and thinking mode controls", () => {
    const disabled = buildDeepSeekChatRequest({
      messages: [{ role: "user", content: "{}" }],
      model: "deepseek-v4-flash",
      thinkingEnabled: false,
    });
    expect(disabled).toMatchObject({
      extra_body: { thinking: { type: "disabled" } },
      model: "deepseek-v4-flash",
      response_format: { type: "json_object" },
      temperature: 0.1,
    });

    const enabled = buildDeepSeekChatRequest({
      messages: [{ role: "user", content: "{}" }],
      model: "deepseek-v4-pro",
      thinkingEnabled: true,
    });
    expect(enabled).toMatchObject({
      extra_body: { thinking: { type: "enabled" } },
      model: "deepseek-v4-pro",
      reasoning_effort: "high",
      response_format: { type: "json_object" },
    });
  });
});

function restoreEnv(name: string, value: string | undefined) {
  if (value === undefined) {
    delete process.env[name];
    return;
  }

  process.env[name] = value;
}
