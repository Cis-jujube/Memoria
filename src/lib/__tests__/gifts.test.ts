import { describe, expect, it } from "vitest";

import { buildGiftCitation, rankGiftIdeas } from "@/lib/gifts";

describe("gift recommendation citations", () => {
  it("formats citations from profile facts and memories", () => {
    expect(
      buildGiftCitation({
        facts: ["likes matcha", "prefers practical gifts"],
        memories: ["mentioned exams are stressful"],
      }),
    ).toBe(
      "Based on facts: likes matcha; prefers practical gifts. Memory signals: mentioned exams are stressful.",
    );
  });

  it("ranks lower-risk practical gifts before vague expensive gifts", () => {
    const ranked = rankGiftIdeas([
      { title: "Luxury headphones", priceBand: "$$$", sourceFactIds: [] },
      {
        title: "Matcha study kit",
        priceBand: "$",
        sourceFactIds: ["likes matcha", "studying for finals"],
      },
    ]);

    expect(ranked[0]?.title).toBe("Matcha study kit");
  });
});
