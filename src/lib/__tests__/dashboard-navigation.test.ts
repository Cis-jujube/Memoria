import { describe, expect, it } from "vitest";

import {
  groupLabelForFilter,
  parseAppSection,
  parseGroupFilter,
  sectionLabel,
} from "@/lib/dashboard-navigation";

describe("dashboard navigation helpers", () => {
  it("parses known section params and falls back to home", () => {
    expect(parseAppSection("people")).toBe("people");
    expect(parseAppSection("brief")).toBe("brief");
    expect(parseAppSection("unknown")).toBe("home");
    expect(parseAppSection(null)).toBe("home");
  });

  it("parses known group filters and maps them to product labels", () => {
    expect(parseGroupFilter("study-abroad")).toBe("study-abroad");
    expect(groupLabelForFilter("study-abroad")).toBe("海外学习");
    expect(parseGroupFilter("not-real")).toBeNull();
  });

  it("returns stable human labels for app sections", () => {
    expect(sectionLabel("home")).toBe("首页");
    expect(sectionLabel("inbox")).toBe("待确认");
    expect(sectionLabel("files")).toBe("文件导入");
  });
});
