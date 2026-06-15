import { describe, expect, it } from "vitest";

import {
  buildDeepSeekChatRequest,
  getNativeCopy,
  normalizeLanguagePreference,
} from "@/lib/local-ai";

describe("local native AI contract", () => {
  it("builds a DeepSeek Flash request with thinking disabled", () => {
    const request = buildDeepSeekChatRequest({
      text: "昨天和 Alex 吃火锅，他不吃香菜",
      model: "deepseek-v4-flash",
      deepThinking: false,
      locale: "zh-CN",
      timezone: "Asia/Shanghai",
    });

    expect(request.model).toBe("deepseek-v4-flash");
    expect(request.thinking).toEqual({ type: "disabled" });
    expect(request.reasoning_effort).toBeUndefined();
    expect(request.response_format).toEqual({ type: "json_object" });
    expect(request.messages[0].content).toContain("JSON");
    expect(request.messages[1].content).toContain("Locale: zh-CN");
  });

  it("builds a DeepSeek Pro request with high-effort thinking enabled", () => {
    const request = buildDeepSeekChatRequest({
      text: "Alex has a calculus midterm next week.",
      model: "deepseek-v4-pro",
      deepThinking: true,
      locale: "en-US",
      timezone: "America/New_York",
    });

    expect(request.model).toBe("deepseek-v4-pro");
    expect(request.thinking).toEqual({ type: "enabled" });
    expect(request.reasoning_effort).toBe("high");
    expect(request.temperature).toBe(0.1);
    expect(request.max_tokens).toBe(1600);
  });

  it("normalizes supported language preferences", () => {
    expect(normalizeLanguagePreference("zh-CN")).toBe("zh-CN");
    expect(normalizeLanguagePreference("en")).toBe("en");
    expect(normalizeLanguagePreference("system")).toBe("system");
    expect(normalizeLanguagePreference("fr")).toBe("system");
  });

  it("keeps Chinese settings copy natural and separate from English", () => {
    const zh = getNativeCopy("zh-CN");
    const en = getNativeCopy("en");

    expect(zh.aiInboxTitle).toBe("待确认");
    expect(zh.whySuggested).toBe("为什么建议这样记");
    expect(zh.deepseekPrivacyNote).toContain("会发送给 DeepSeek");
    expect(en.aiInboxTitle).toBe("AI Inbox");
    expect(en.whySuggested).toBe("Why AI suggested this");
  });
});
