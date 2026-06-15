import { describe, expect, it } from "vitest";

import { buildPersonPatchForPendingUpdate } from "@/lib/friend-memory";

describe("friend memory pending update review", () => {
  it("merges preference proposed values without dropping existing profile data", () => {
    const patch = buildPersonPatchForPendingUpdate({
      current: {
        preferences: {
          favoriteFoods: ["matcha"],
          profileTags: ["study"],
        },
        communication: {
          style: "WeChat first",
        },
        importantFacts: ["Has a calculus midterm."],
        sourceSummary: "Older note",
      },
      fieldPath: "preferences.favoriteFoods",
      proposedValue: ["hotpot", "matcha"],
      summary: "Alex likes hotpot.",
      evidence: "Alex said he wants hotpot after finals.",
    });

    expect(patch).toEqual({
      preferences: {
        favoriteFoods: ["matcha", "hotpot"],
        profileTags: ["study"],
      },
      communication: {
        style: "WeChat first",
      },
      importantFacts: [
        "Has a calculus midterm.",
        "Alex likes hotpot.",
        "Alex said he wants hotpot after finals.",
      ],
      sourceSummary: "Alex likes hotpot.",
    });
  });

  it("applies communication field paths to communication data", () => {
    const patch = buildPersonPatchForPendingUpdate({
      current: {
        preferences: {},
        communication: {
          style: "Text before calls",
        },
        importantFacts: [],
        sourceSummary: null,
      },
      fieldPath: "communication.channel",
      proposedValue: "Signal",
      summary: "Alex prefers Signal.",
      evidence: "Alex asked to use Signal for trip plans.",
    });

    expect(patch.communication).toEqual({
      style: "Text before calls",
      channel: "Signal",
    });
    expect(patch.importantFacts).toEqual([
      "Alex prefers Signal.",
      "Alex asked to use Signal for trip plans.",
    ]);
  });
});
