import { describe, expect, it } from "vitest";

import { demoDashboardData } from "@/data/demo";
import { deriveDashboardAnalytics } from "@/lib/dashboard-analytics";

describe("deriveDashboardAnalytics", () => {
  it("derives chart-ready counts from dashboard data", () => {
    const analytics = deriveDashboardAnalytics(demoDashboardData);

    expect(analytics.relationshipHealth).toEqual({
      activePeople: 3,
      pendingReviews: 3,
      upcomingReminders: 3,
      giftOpportunities: 2,
    });
    expect(analytics.groupCounts).toEqual([
      { label: "同学", count: 1 },
      { label: "老朋友", count: 1 },
      { label: "实习圈", count: 1 },
    ]);
    expect(analytics.pendingTypeCounts).toEqual([
      { label: "事件", count: 1 },
      { label: "偏好", count: 1 },
      { label: "生日", count: 1 },
    ]);
    expect(analytics.fileStatusCounts).toEqual([
      { label: "23 notes extracted", count: 1 },
      { label: "OCR processing", count: 1 },
    ]);
    expect(analytics.activityTimeline).toHaveLength(4);
    expect(analytics.activityTimeline[0]).toMatchObject({
      label: "待确认",
      count: 3,
    });
    expect(analytics.focusItems).toEqual([
      {
        id: "review-p1",
        label: "确认 Alex Chen 的新信息",
        detail: "Alex 吃了火锅，他不吃香菜，喜欢毛肚和虾滑。",
        section: "inbox",
        priority: "high",
      },
      {
        id: "reminder-r1",
        label: "记得联系 May Zhang",
        detail: "May Zhang 生日 · 5 月 16 日 · 2 天后",
        section: "reminders",
        priority: "high",
      },
      {
        id: "gift-g1",
        label: "May Zhang 的礼物灵感",
        detail: "BYREDO 香氛礼盒 · $$",
        section: "gifts",
        priority: "medium",
      },
    ]);
    expect(analytics.askSuggestions).toEqual([
      "Alex Chen 的待确认里有什么？",
      "这周该多关心谁？",
      "May Zhang 适合什么礼物？",
    ]);
    expect(analytics.nextActionsByPerson["demo-alex"]).toBe(
      "确认 2 条待处理信息",
    );
  });

  it("returns empty chart data instead of throwing for empty dashboards", () => {
    const analytics = deriveDashboardAnalytics({
      stats: { inbox: 0, reminders: 0, birthdays: 0, files: 0 },
      groups: [],
      people: [],
      pendingUpdates: [],
      reminders: [],
      calendarEvents: [],
      relationshipScores: [],
      relationshipGraph: {
        me: { id: "me", name: "Me", initials: "M" },
        groups: [],
        nodes: [],
        edges: [],
      },
      gifts: [],
      files: [],
    });

    expect(analytics.groupCounts).toEqual([]);
    expect(analytics.pendingTypeCounts).toEqual([]);
    expect(analytics.fileStatusCounts).toEqual([]);
    expect(analytics.activityTimeline).toEqual([
      { label: "待确认", count: 0 },
      { label: "朋友", count: 0 },
      { label: "提醒", count: 0 },
      { label: "礼物", count: 0 },
    ]);
    expect(analytics.focusItems).toEqual([]);
    expect(analytics.askSuggestions).toEqual([
      "最近应该联系谁？",
      "接下来有哪些生日？",
      "见面前我该先想起什么？",
    ]);
    expect(analytics.nextActionsByPerson).toEqual({});
  });
});
