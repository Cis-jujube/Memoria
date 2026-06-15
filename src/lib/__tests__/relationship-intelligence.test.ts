import { describe, expect, it } from "vitest";

import { demoDashboardData } from "@/data/demo";
import {
  buildRelationshipGraph,
  deriveCalendarEvents,
  deriveRelationshipScores,
  enrichDashboardData,
} from "@/lib/relationship-intelligence";

describe("relationship intelligence", () => {
  it("derives birthdays, reminders, gifts, and AI suggestions as calendar events", () => {
    const events = deriveCalendarEvents(
      demoDashboardData,
      new Date("2026-05-10T00:00:00.000Z"),
    );

    expect(events.some((event) => event.type === "birthday")).toBe(true);
    expect(events.some((event) => event.type === "gift")).toBe(true);
    expect(events.some((event) => event.type === "life_event")).toBe(true);
    expect(events.some((event) => event.type === "ai_suggestion")).toBe(true);
    expect(events[0].date <= events[events.length - 1].date).toBe(true);
  });

  it("scores relationship maintenance with natural Chinese guidance", () => {
    const scores = deriveRelationshipScores(demoDashboardData);
    const alex = scores.find((score) => score.personName === "Alex Chen");

    expect(alex?.total).toBeGreaterThan(70);
    expect(alex?.explanation).toContain("Alex Chen");
    expect(alex?.recommendation).not.toMatch(/translation|machine/i);
  });

  it("builds a Me-centered graph from the signed-in user profile", () => {
    const graph = buildRelationshipGraph(demoDashboardData, {
      id: "user-1",
      name: "Jujube Wang",
      scores: demoDashboardData.relationshipScores,
    });

    expect(graph.me).toMatchObject({
      id: "user-1",
      initials: "JW",
      name: "Jujube Wang",
    });
    expect(graph.edges.every((edge) => edge.source === "user-1")).toBe(true);
  });

  it("recomputes graph and group counts after enrichment", () => {
    const enriched = enrichDashboardData({
      ...demoDashboardData,
      groups: [],
      relationshipGraph: {
        me: { id: "me", name: "Me", initials: "M" },
        groups: [],
        nodes: [],
        edges: [],
      },
      relationshipScores: [],
      calendarEvents: [],
    });

    expect(enriched.groups.map((group) => group.label)).toEqual([
      "同学",
      "老朋友",
      "实习圈",
    ]);
    expect(enriched.relationshipGraph.nodes).toHaveLength(3);
  });
});
