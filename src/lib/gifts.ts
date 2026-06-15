export type GiftCandidate = {
  title: string;
  priceBand?: string | null;
  sourceFactIds: string[];
};

export function buildGiftCitation({
  facts,
  memories,
}: {
  facts: string[];
  memories: string[];
}) {
  const factText = facts.length
    ? `Based on facts: ${facts.join("; ")}.`
    : "Based on saved profile facts.";
  const memoryText = memories.length
    ? ` Memory signals: ${memories.join("; ")}.`
    : "";
  return `${factText}${memoryText}`;
}

export function rankGiftIdeas<T extends GiftCandidate>(ideas: T[]) {
  return [...ideas].sort((left, right) => scoreGift(right) - scoreGift(left));
}

function scoreGift(idea: GiftCandidate) {
  const evidenceScore = idea.sourceFactIds.length * 10;
  const priceScore =
    idea.priceBand === "$"
      ? 4
      : idea.priceBand === "$$"
        ? 2
        : idea.priceBand === "$$$"
          ? -2
          : 0;
  const vaguePenalty = idea.sourceFactIds.length === 0 ? -8 : 0;
  return evidenceScore + priceScore + vaguePenalty;
}
