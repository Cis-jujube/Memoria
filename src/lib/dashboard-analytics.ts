import type { DashboardData } from "@/data/demo";
import type { AppSection } from "@/lib/dashboard-navigation";

type CountItem = {
  label: string;
  count: number;
};

export type FocusItem = {
  id: string;
  label: string;
  detail: string;
  section: AppSection;
  priority: "high" | "medium" | "low";
};

export type DashboardAnalytics = {
  relationshipHealth: {
    activePeople: number;
    pendingReviews: number;
    upcomingReminders: number;
    giftOpportunities: number;
  };
  groupCounts: CountItem[];
  pendingTypeCounts: CountItem[];
  reminderWindowCounts: CountItem[];
  fileStatusCounts: CountItem[];
  activityTimeline: CountItem[];
  focusItems: FocusItem[];
  askSuggestions: string[];
  nextActionsByPerson: Record<string, string>;
};

export function deriveDashboardAnalytics(
  dashboard: DashboardData,
): DashboardAnalytics {
  return {
    relationshipHealth: {
      activePeople: dashboard.people.length,
      pendingReviews: dashboard.pendingUpdates.length,
      upcomingReminders: dashboard.reminders.length,
      giftOpportunities: dashboard.gifts.length,
    },
    groupCounts: dashboard.groups.length
      ? dashboard.groups.map((group) => ({
          label: group.label,
          count: group.memberCount,
        }))
      : countBy(dashboard.people.map((person) => person.groupLabel || "朋友")),
    pendingTypeCounts: countBy(
      dashboard.pendingUpdates.map((update) => update.type || "Update"),
    ),
    reminderWindowCounts: countBy(
      dashboard.reminders.map((reminder) => reminderWindow(reminder.dueLabel)),
    ),
    fileStatusCounts: countBy(
      dashboard.files.map((file) => file.status || "未知状态"),
    ),
    activityTimeline: [
      { label: "待确认", count: dashboard.pendingUpdates.length },
      { label: "朋友", count: dashboard.people.length },
      { label: "提醒", count: dashboard.reminders.length },
      { label: "礼物", count: dashboard.gifts.length },
    ],
    focusItems: buildFocusItems(dashboard),
    askSuggestions: buildAskSuggestions(dashboard),
    nextActionsByPerson: buildNextActionsByPerson(dashboard),
  };
}

function countBy(values: string[]): CountItem[] {
  const counts = new Map<string, number>();

  for (const rawValue of values) {
    const value = rawValue.trim() || "未知";
    counts.set(value, (counts.get(value) || 0) + 1);
  }

  return Array.from(counts.entries())
    .map(([label, count]) => ({ label, count }))
    .sort((first, second) => first.label.localeCompare(second.label));
}

function reminderWindow(label: string): string {
  const normalized = label.toLowerCase();

  if (normalized.includes("today") || label.includes("今天")) return "今天";
  if (normalized.includes("tomorrow") || label.includes("明天")) return "明天";
  if (normalized.includes("day") || normalized.includes("week") || label.includes("天")) {
    return "本周";
  }

  return "已安排";
}

function buildFocusItems(dashboard: DashboardData): FocusItem[] {
  const items: FocusItem[] = [];
  const firstUpdate = dashboard.pendingUpdates[0];
  const firstReminder = dashboard.reminders[0];
  const firstGift = dashboard.gifts[0];

  if (firstUpdate) {
    items.push({
      id: `review-${firstUpdate.id}`,
      label: `确认 ${firstUpdate.personName} 的新信息`,
      detail: firstUpdate.summary,
      section: "inbox",
      priority: "high",
    });
  }

  if (firstReminder) {
    items.push({
      id: `reminder-${firstReminder.id}`,
      label: `记得联系 ${firstReminder.personName}`,
      detail: `${firstReminder.title} · ${firstReminder.dueLabel}`,
      section: "reminders",
      priority: "high",
    });
  }

  if (firstGift) {
    items.push({
      id: `gift-${firstGift.id}`,
      label: `${firstGift.personName} 的礼物灵感`,
      detail: `${firstGift.title} · ${firstGift.priceBand}`,
      section: "gifts",
      priority: "medium",
    });
  }

  return items;
}

function buildAskSuggestions(dashboard: DashboardData): string[] {
  const firstUpdate = dashboard.pendingUpdates[0];
  const firstGift = dashboard.gifts[0];

  if (!firstUpdate && !firstGift && !dashboard.reminders.length) {
    return [
      "最近应该联系谁？",
      "接下来有哪些生日？",
      "见面前我该先想起什么？",
    ];
  }

  return [
    firstUpdate
      ? `${firstUpdate.personName} 的待确认里有什么？`
      : "今天有哪些待确认？",
    "这周该多关心谁？",
    firstGift ? `${firstGift.personName} 适合什么礼物？` : "我现在有哪些礼物灵感？",
  ];
}

function buildNextActionsByPerson(
  dashboard: DashboardData,
): Record<string, string> {
  const pendingCounts = countPeople(dashboard.pendingUpdates.map((item) => item.personName));
  const reminderCounts = countPeople(dashboard.reminders.map((item) => item.personName));
  const giftCounts = countPeople(dashboard.gifts.map((item) => item.personName));

  return Object.fromEntries(
    dashboard.people.map((person) => {
      const pending = pendingCounts.get(person.displayName) || 0;
      const reminders = reminderCounts.get(person.displayName) || 0;
      const gifts = giftCounts.get(person.displayName) || 0;

      if (pending) {
        return [person.id, `确认 ${pending} 条待处理信息`];
      }

      if (reminders) {
        return [person.id, `准备 ${reminders} 个近期提醒`];
      }

      if (gifts) {
        return [person.id, `看看 ${gifts} 条礼物灵感`];
      }

      return [person.id, "补一条最近互动"];
    }),
  );
}

function countPeople(names: string[]): Map<string, number> {
  const counts = new Map<string, number>();

  for (const name of names) {
    counts.set(name, (counts.get(name) || 0) + 1);
  }

  return counts;
}
