import {
  type DashboardCalendarEvent,
  type DashboardData,
  type DashboardGroup,
  type DashboardRelationshipGraph,
  type DashboardRelationshipScore,
} from "@/data/demo";

type MeProfile = {
  id?: string | null;
  name?: string | null;
  email?: string | null;
};

const eventTypeLabels: Record<DashboardCalendarEvent["type"], string> = {
  ai_suggestion: "待确认",
  birthday: "生日",
  gift: "礼物时机",
  life_event: "重要节点",
  reminder: "提醒",
};

const defaultGroupColors = [
  "#256f56",
  "#8f5a33",
  "#365d8c",
  "#7b3f5c",
  "#6f6b2f",
  "#355f67",
];

export function enrichDashboardData(
  dashboard: DashboardData,
  me: MeProfile = {},
): DashboardData {
  const groups = normalizeGroups(dashboard.groups, dashboard.people);
  const base: DashboardData = {
    ...dashboard,
    groups,
    people: dashboard.people.map((person) => {
      const groupLabels = person.groupLabels.length
        ? person.groupLabels
        : [person.groupLabel || "朋友"];
      const knownGroupIds = person.groupIds.filter((groupId) =>
        groups.some((group) => group.id === groupId),
      );
      const groupIds = knownGroupIds.length
        ? knownGroupIds
        : groupLabels.map((label) => groupIdForLabel(label, groups));

      return {
        ...person,
        groupIds,
        groupLabels,
        groupLabel: groupLabels[0] || person.groupLabel || "朋友",
      };
    }),
  };
  const relationshipScores = deriveRelationshipScores(base);

  return {
    ...base,
    calendarEvents: deriveCalendarEvents(base),
    relationshipScores,
    relationshipGraph: buildRelationshipGraph(base, {
      ...me,
      scores: relationshipScores,
    }),
  };
}

export function normalizeGroups(
  groups: DashboardGroup[],
  people: DashboardData["people"],
): DashboardGroup[] {
  const seen = new Map<string, DashboardGroup>();

  for (const group of groups) {
    seen.set(group.id, {
      ...group,
      memberCount: people.filter((person) =>
        person.groupIds.includes(group.id) ||
        person.groupLabels.includes(group.label) ||
        person.groupLabel === group.label,
      ).length,
    });
  }

  for (const person of people) {
    const labels = person.groupLabels.length
      ? person.groupLabels
      : [person.groupLabel || "朋友"];

    for (const label of labels) {
      if ([...seen.values()].some((group) => group.label === label)) continue;
      const id = slugGroupId(label);
      seen.set(id, {
        id,
        label,
        color: defaultGroupColors[seen.size % defaultGroupColors.length],
        description: "从联系人资料自动整理出来的分组。",
        memberCount: 0,
        sortOrder: seen.size,
      });
    }
  }

  return [...seen.values()]
    .map((group) => ({
      ...group,
      memberCount: people.filter((person) =>
        person.groupIds.includes(group.id) ||
        person.groupLabels.includes(group.label) ||
        person.groupLabel === group.label,
      ).length,
    }))
    .sort((first, second) => first.sortOrder - second.sortOrder);
}

export function deriveCalendarEvents(
  dashboard: DashboardData,
  now = new Date(),
): DashboardCalendarEvent[] {
  const events: DashboardCalendarEvent[] = [];

  for (const reminder of dashboard.reminders) {
    events.push({
      id: `reminder-${reminder.id}`,
      title: reminder.title,
      personName: reminder.personName,
      date: reminder.dueAt,
      type: reminder.type === "life_event" ? "life_event" : "reminder",
      typeLabel:
        reminder.type === "life_event"
          ? eventTypeLabels.life_event
          : eventTypeLabels.reminder,
      dayLabel: formatMonthDay(new Date(reminder.dueAt)),
      density: reminder.type === "life_event" ? 3 : 2,
      sourceId: reminder.id,
    });
  }

  for (const person of dashboard.people) {
    if (!person.birthdayMonth || !person.birthdayDay) continue;
    const date = nextAnnualDate(person.birthdayMonth, person.birthdayDay, now);
    events.push({
      id: `birthday-${person.id}`,
      title: `${person.displayName} 生日`,
      personName: person.displayName,
      date: date.toISOString(),
      type: "birthday",
      typeLabel: eventTypeLabels.birthday,
      dayLabel: formatMonthDay(date),
      density: 3,
      sourceId: person.id,
    });
  }

  for (const gift of dashboard.gifts.slice(0, 4)) {
    const person = dashboard.people.find((item) => item.displayName === gift.personName);
    const date =
      person?.birthdayMonth && person.birthdayDay
        ? addDays(nextAnnualDate(person.birthdayMonth, person.birthdayDay, now), -7)
        : addDays(now, 14);

    events.push({
      id: `gift-${gift.id}`,
      title: `准备礼物：${gift.title}`,
      personName: gift.personName,
      date: date.toISOString(),
      type: "gift",
      typeLabel: eventTypeLabels.gift,
      dayLabel: formatMonthDay(date),
      density: 2,
      sourceId: gift.id,
    });
  }

  for (const update of dashboard.pendingUpdates.slice(0, 5)) {
    if (!/生日|birthday|考试|面试|搬家|毕业|旅行|入职|换工作/i.test(update.summary)) {
      continue;
    }
    const date = addDays(now, events.length + 1);
    events.push({
      id: `suggestion-${update.id}`,
      title: update.summary,
      personName: update.personName,
      date: date.toISOString(),
      type: "ai_suggestion",
      typeLabel: eventTypeLabels.ai_suggestion,
      dayLabel: formatMonthDay(date),
      density: 1,
      sourceId: update.id,
    });
  }

  return events.sort(
    (first, second) =>
      new Date(first.date).getTime() - new Date(second.date).getTime(),
  );
}

export function deriveRelationshipScores(
  dashboard: DashboardData,
): DashboardRelationshipScore[] {
  return dashboard.people.map((person) => {
    const pending = dashboard.pendingUpdates.filter(
      (item) => item.personName === person.displayName,
    ).length;
    const reminders = dashboard.reminders.filter(
      (item) => item.personName === person.displayName,
    ).length;
    const gifts = dashboard.gifts.filter(
      (item) => item.personName === person.displayName,
    ).length;
    const profileFields = [
      person.birthday !== "Not set" ? person.birthday : "",
      person.dietaryRestrictions,
      person.favoriteFoods,
      person.dislikedThings,
      person.zodiacSign,
      person.mbti,
      person.interests,
      person.books,
      person.sports,
      person.favoriteThings,
      person.games,
      person.gameTime,
      person.musicAndMedia,
      person.studyNotes,
      person.careerNotes,
      person.lifeNotes,
      person.relationshipNotes,
      person.travel,
      person.communicationStyle,
      person.profileTags,
      person.location,
    ].filter(isMeaningfulValue).length;
    const boundarySignals = [person.dietaryRestrictions, person.dislikedThings]
      .filter(isMeaningfulValue).length;
    const lifeSignals = [person.lifeNotes, person.travel, person.communicationStyle]
      .filter(isMeaningfulValue).length;
    const studyCareerSignals = [person.studyNotes, person.careerNotes]
      .filter(isMeaningfulValue).length;
    const emotionalSignals = [person.relationshipNotes, person.communicationStyle]
      .filter(isMeaningfulValue).length;
    const tasteSignals = [
      person.favoriteFoods,
      person.favoriteThings,
      person.dislikedThings,
      person.musicAndMedia,
      person.books,
    ].filter(isMeaningfulValue).length;
    const playSignals = [person.games, person.gameTime, person.sports]
      .filter(isMeaningfulValue).length;

    const freshness = clampScore(55 + pending * 12 + reminders * 10);
    const profileDepth = clampScore(24 + profileFields * 4.5);
    const milestoneCoverage = clampScore(
      40 +
        (person.birthdayMonth && person.birthdayDay ? 25 : 0) +
        reminders * 12 +
        gifts * 8,
    );
    const interactionWarmth = clampScore(
      45 + gifts * 14 + pending * 8 + (person.lastSignal ? 8 : 0),
    );
    const boundaryCare = clampScore(45 + boundarySignals * 22);
    const lifeContext = clampScore(42 + lifeSignals * 16 + (person.location ? 8 : 0));
    const studyCareer = clampScore(38 + studyCareerSignals * 22);
    const emotionalContext = clampScore(36 + emotionalSignals * 22);
    const tasteMap = clampScore(34 + tasteSignals * 12);
    const playCulture = clampScore(36 + playSignals * 18);
    const total = Math.round(
      freshness * 0.12 +
        profileDepth * 0.14 +
        milestoneCoverage * 0.12 +
        interactionWarmth * 0.1 +
        boundaryCare * 0.1 +
        lifeContext * 0.11 +
        studyCareer * 0.1 +
        emotionalContext * 0.1 +
        tasteMap * 0.11 +
        playCulture * 0.1,
    );

    return {
      personId: person.id,
      personName: person.displayName,
      total,
      freshness,
      profileDepth,
      milestoneCoverage,
      interactionWarmth,
      boundaryCare,
      lifeContext,
      studyCareer,
      emotionalContext,
      tasteMap,
      playCulture,
      explanation: scoreExplanation({
        personName: person.displayName,
        pending,
        reminders,
        gifts,
        profileDepth,
        boundaryCare,
        lifeContext,
        studyCareer,
        emotionalContext,
        tasteMap,
        playCulture,
      }),
      recommendation: scoreRecommendation({
        personName: person.displayName,
        reminders,
        gifts,
        boundaryCare,
      }),
    };
  });
}

export function buildRelationshipGraph(
  dashboard: DashboardData,
  me: MeProfile & { scores?: DashboardRelationshipScore[] } = {},
): DashboardRelationshipGraph {
  const groups = normalizeGroups(dashboard.groups, dashboard.people);
  const scores = me.scores || dashboard.relationshipScores || [];

  return {
    me: {
      id: me.id || "me",
      name: me.name || me.email?.split("@")[0] || "Me",
      initials: initialsFor(me.name || me.email || "Me"),
    },
    groups: groups.map((group, index) => ({
      id: group.id,
      label: group.label,
      color: group.color,
      memberCount: group.memberCount,
      orbit: index + 1,
    })),
    nodes: dashboard.people.map((person, index) => {
      const score =
        scores.find((item) => item.personId === person.id)?.total ||
        dashboard.relationshipScores.find((item) => item.personId === person.id)
          ?.total ||
        60;
      const groupId =
        person.groupIds[0] || groupIdForLabel(person.groupLabel, groups) || groups[0]?.id || "friends";
      const group = groups.find((item) => item.id === groupId);

      return {
        id: person.id,
        label: person.displayName,
        initials: person.initials,
        groupId,
        groupLabel: group?.label || person.groupLabel || "朋友",
        score,
        strength: Number((score / 100).toFixed(2)),
        lastSignal: person.lastSignal,
        hasUpcoming: dashboard.reminders.some(
          (reminder) => reminder.personName === person.displayName,
        ),
        hasBirthday: Boolean(person.birthdayMonth && person.birthdayDay),
        orbitIndex: index,
      };
    }),
    edges: dashboard.people.map((person) => ({
      id: `me-${person.id}`,
      source: me.id || "me",
      target: person.id,
      label: person.relationLabel,
      strength: Math.max(
        1,
        Math.round(
          ((scores.find((item) => item.personId === person.id)?.total || 60) / 100) *
            5,
        ),
      ),
    })),
  };
}

function scoreExplanation({
  boundaryCare,
  emotionalContext,
  gifts,
  lifeContext,
  pending,
  playCulture,
  personName,
  profileDepth,
  reminders,
  studyCareer,
  tasteMap,
}: {
  boundaryCare: number;
  emotionalContext: number;
  gifts: number;
  lifeContext: number;
  pending: number;
  playCulture: number;
  personName: string;
  profileDepth: number;
  reminders: number;
  studyCareer: number;
  tasteMap: number;
}) {
  if (pending > 0) {
    return `${personName} 还有 ${pending} 条待确认信息，先把证据确认好，再决定要不要写进档案。`;
  }
  if (reminders > 0 || gifts > 0) {
    return `${personName} 近期有提醒或礼物线索，适合提前准备，不要等到当天才临时补救。`;
  }
  if (profileDepth < 60) {
    return `${personName} 的资料还偏薄，下次可以自然补一点生活、学习、喜好或最近在玩的东西。`;
  }
  if (boundaryCare < 70) {
    return `${personName} 的边界和雷点记录还不够，送礼或约饭前最好再确认一下。`;
  }
  if (lifeContext < 65 || studyCareer < 65) {
    return `${personName} 的生活和学习/事业线索还可以再补，关系维护会更有上下文。`;
  }
  if (emotionalContext < 65) {
    return `${personName} 的情绪和关系边界还不够清楚，关心时要更轻一点。`;
  }
  if (tasteMap < 70 || playCulture < 70) {
    return `${personName} 的口味、游戏、音乐或运动线索还可以更具体，礼物和聊天会更准。`;
  }
  return `${personName} 的画像已经比较立体，保持轻量、真诚、具体的联系就好。`;
}

function scoreRecommendation({
  boundaryCare,
  gifts,
  personName,
  reminders,
}: {
  boundaryCare: number;
  gifts: number;
  personName: string;
  reminders: number;
}) {
  if (reminders > 0) {
    return `看一眼 ${personName} 最近的提醒，发一条具体但不打扰的问候。`;
  }
  if (gifts > 0) {
    return `礼物建议先放进备选清单，再结合预算和场合确认。`;
  }
  if (boundaryCare < 70) {
    return `先补充忌口、不喜欢的东西和沟通边界，再做下一步行动。`;
  }
  return `记录下一次真实互动，别为了维护关系而硬聊。`;
}

function groupIdForLabel(label: string, groups: DashboardGroup[]) {
  return groups.find((group) => group.label === label)?.id || slugGroupId(label);
}

function slugGroupId(label: string) {
  const slug = label
    .normalize("NFKC")
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "-")
    .replace(/^-|-$/g, "");
  return `group-${slug || "friends"}`;
}

function isMeaningfulValue(value: string) {
  const normalized = value.trim().toLowerCase();
  return Boolean(
    normalized &&
      normalized !== "not set" &&
      normalized !== "unknown" &&
      normalized !== "none",
  );
}

function clampScore(value: number) {
  return Math.max(0, Math.min(100, Math.round(value)));
}

function nextAnnualDate(month: number, day: number, now: Date) {
  const currentYear = now.getFullYear();
  const candidate = new Date(Date.UTC(currentYear, month - 1, day, 9, 0, 0));
  if (candidate.getTime() < now.getTime()) {
    return new Date(Date.UTC(currentYear + 1, month - 1, day, 9, 0, 0));
  }
  return candidate;
}

function addDays(date: Date, days: number) {
  const result = new Date(date);
  result.setUTCDate(result.getUTCDate() + days);
  return result;
}

function formatMonthDay(date: Date) {
  return date.toLocaleDateString("zh-CN", {
    day: "numeric",
    month: "short",
    timeZone: "UTC",
  });
}

function initialsFor(value: string) {
  const parts = value
    .replace(/@.*/, "")
    .split(/\s+/)
    .filter(Boolean);
  return (parts[0]?.[0] || "M").toUpperCase() + (parts[1]?.[0] || "").toUpperCase();
}
