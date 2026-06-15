import { addDays, formatDistanceToNowStrict } from "date-fns";

import {
  type DeepSeekRequestOptions,
  normalizeExtractionToPendingUpdates,
  extractFriendMemory,
} from "@/lib/ai";
import { Prisma } from "@/generated/prisma/client";
import { publicApiError } from "@/lib/api";
import { prisma } from "@/lib/db";
import { demoDashboardData, type DashboardData } from "@/data/demo";
import { requireOwnedPersonId } from "@/lib/people";
import { enrichDashboardData } from "@/lib/relationship-intelligence";

export async function getDashboardData(
  userId?: string,
  userName?: string,
): Promise<DashboardData> {
  if (!userId) return demoDashboardData;

  try {
    const [
      people,
      contactGroups,
      pendingUpdates,
      reminders,
      gifts,
      files,
      pendingUpdateCount,
      activeReminderCount,
      birthdayCount,
      processingFileCount,
    ] = await Promise.all([
      prisma.person.findMany({
        where: { userId },
        orderBy: { updatedAt: "desc" },
        take: 6,
        include: { groups: { include: { group: true } } },
      }),
      prisma.contactGroup.findMany({
        where: { userId },
        orderBy: [{ sortOrder: "asc" }, { label: "asc" }],
        include: { _count: { select: { members: true } } },
      }),
      prisma.pendingUpdate.findMany({
        where: { userId, status: "PENDING" },
        orderBy: { createdAt: "desc" },
        take: 8,
        include: { person: true },
      }),
      prisma.reminder.findMany({
        where: { userId, status: "ACTIVE" },
        orderBy: { dueAt: "asc" },
        take: 6,
        include: { person: true },
      }),
      prisma.giftIdea.findMany({
        where: { userId },
        orderBy: { updatedAt: "desc" },
        take: 6,
        include: { person: true },
      }),
      prisma.uploadedFile.findMany({
        where: { userId },
        orderBy: { updatedAt: "desc" },
        take: 6,
      }),
      prisma.pendingUpdate.count({ where: { userId, status: "PENDING" } }),
      prisma.reminder.count({ where: { userId, status: "ACTIVE" } }),
      prisma.person.count({ where: { userId, birthdayMonth: { not: null } } }),
      prisma.uploadedFile.count({ where: { userId, status: "PROCESSING" } }),
    ]);

    return enrichDashboardData({
      stats: {
        inbox: pendingUpdateCount,
        reminders: activeReminderCount,
        birthdays: birthdayCount,
        files: processingFileCount,
      },
      groups: contactGroups.map((group) => ({
        id: group.id,
        label: group.label,
        color: group.color,
        description: group.description || "私人关系分组。",
        memberCount: group._count.members,
        sortOrder: group.sortOrder,
      })),
      people: people.map((person) => ({
        id: person.id,
        displayName: person.displayName,
        relationLabel: person.relationLabel || "朋友",
        groupLabel: person.groups[0]?.group.label || person.groupLabel || "朋友",
        groupIds: person.groups.map((membership) => membership.groupId),
        groupLabels: person.groups.map((membership) => membership.group.label),
        location: person.location || "还没记",
        birthday:
          person.birthdayMonth && person.birthdayDay
            ? `${person.birthdayMonth}/${person.birthdayDay}`
            : "Not set",
        birthdayMonth: person.birthdayMonth || undefined,
        birthdayDay: person.birthdayDay || undefined,
        dietaryRestrictions: preferenceField(person.preferences, "dietaryRestrictions"),
        favoriteFoods: preferenceField(person.preferences, "favoriteFoods"),
        dislikedThings: preferenceField(person.preferences, "dislikedThings"),
        zodiacSign: preferenceField(person.preferences, "zodiacSign"),
        mbti: preferenceField(person.preferences, "mbti"),
        interests: preferenceField(person.preferences, "interests"),
        books: preferenceField(person.preferences, "books"),
        sports: preferenceField(person.preferences, "sports"),
        favoriteThings: preferenceField(person.preferences, "favoriteThings"),
        games: preferenceField(person.preferences, "games"),
        gameTime: preferenceField(person.preferences, "gameTime"),
        musicAndMedia: preferenceField(person.preferences, "musicAndMedia"),
        studyNotes: preferenceField(person.preferences, "studyNotes"),
        careerNotes: preferenceField(person.preferences, "careerNotes"),
        lifeNotes: preferenceField(person.preferences, "lifeNotes"),
        relationshipNotes: preferenceField(person.preferences, "relationshipNotes"),
        travel: preferenceField(person.preferences, "travel"),
        communicationStyle:
          preferenceField(person.communication, "style") !== "Not set"
            ? preferenceField(person.communication, "style")
            : preferenceField(person.preferences, "communicationStyle"),
        profileTags: preferenceField(person.preferences, "profileTags"),
        lastSignal: person.sourceSummary || "还没有近期记录",
        initials: initialsFor(person.displayName),
      })),
      pendingUpdates: pendingUpdates.map((update) => ({
        id: update.id,
        type: update.type,
        summary: update.summary,
        evidence: update.evidence,
        personName: update.person?.displayName || "未关联联系人",
        createdLabel: formatDistanceToNowStrict(update.createdAt, {
          addSuffix: true,
        }),
      })),
      reminders: reminders.map((reminder) => ({
        id: reminder.id,
        title: reminder.title,
        personName: reminder.person?.displayName || "通用",
        dueAt: reminder.dueAt.toISOString(),
        type: classifyReminderType(reminder.title),
        dueLabel: `${reminder.dueAt.toLocaleDateString()} · ${formatDistanceToNowStrict(
          reminder.dueAt,
          { addSuffix: true },
        )}`,
      })),
      calendarEvents: [],
      relationshipScores: [],
      relationshipGraph: {
        me: {
          id: userId,
          initials: initialsFor(userName || "Me"),
          name: userName || "Me",
        },
        groups: [],
        nodes: [],
        edges: [],
      },
      gifts: gifts.map((gift) => ({
        id: gift.id,
        title: gift.title,
        personName: gift.person.displayName,
        priceBand: gift.priceBand || "$",
        rationale: gift.rationale,
      })),
      files: files.map((file) => ({
        id: file.id,
        filename: file.filename,
        status: file.status.toLowerCase(),
        progress: file.status === "READY" ? 100 : file.status === "FAILED" ? 0 : 64,
      })),
    }, { id: userId });
  } catch {
    return demoDashboardData;
  }
}

export async function captureNaturalLanguageMemory({
  deepSeek,
  userId,
  text,
}: {
  deepSeek?: DeepSeekRequestOptions;
  userId: string;
  text: string;
}) {
  const trimmed = text.trim();
  if (trimmed.length < 3) {
    throw publicApiError("Capture text is too short", 422);
  }

  const memory = await prisma.memory.create({
    data: {
      userId,
      title: summarizeTitle(trimmed),
      body: trimmed,
      sourceType: "natural_language",
      confidence: 1,
    },
  });

  const extraction = await extractFriendMemory({ text: trimmed }, { deepSeek });
  const normalized = normalizeExtractionToPendingUpdates({
    userId,
    sourceId: memory.id,
    sourceType: "natural_language",
    extraction,
  });

  const created = [];
  for (const update of normalized) {
    const person = update.personName
      ? await findOrCreatePerson(userId, update.personName)
      : null;
    created.push(
      await prisma.pendingUpdate.create({
        data: {
          userId,
          personId: person?.id,
          type: update.type,
          fieldPath: update.fieldPath,
          proposedValue: toPrismaJson(update.proposedValue),
          summary: update.summary,
          evidence: update.evidence,
          sourceType: update.sourceType,
          sourceId: update.sourceId,
          confidence: update.confidence,
        },
      }),
    );
  }

  await prisma.auditEvent.create({
    data: {
      userId,
      action: "capture.created",
      entityType: "Memory",
      entityId: memory.id,
      metadata: { pendingUpdateCount: created.length },
    },
  });

  return { memory, pendingUpdates: created };
}

export async function reviewPendingUpdate({
  userId,
  updateId,
  action,
}: {
  userId: string;
  updateId: string;
  action: "confirm" | "discard";
}) {
  return prisma.$transaction(async (tx) => {
    const update = await tx.pendingUpdate.findFirst({
      where: { id: updateId, userId },
      include: { person: true },
    });

    if (!update) {
      throw publicApiError("Pending update was not found", 404);
    }

    if (update.status !== "PENDING") {
      throw publicApiError("Pending update has already been reviewed", 409);
    }

    if (action === "discard") {
      await tx.auditEvent.create({
        data: {
          userId,
          action: "pending_update.discarded",
          entityType: "PendingUpdate",
          entityId: update.id,
          metadata: { type: update.type, fieldPath: update.fieldPath },
        },
      });

      return tx.pendingUpdate.update({
        where: { id: update.id },
        data: { status: "DISCARDED", reviewedAt: new Date() },
      });
    }

    if (update.type === "REMINDER") {
      const value = asObject(update.proposedValue) as { title?: string; dueAt?: string };
      await tx.reminder.create({
        data: {
          userId,
          personId: update.personId,
          title: value.title || update.summary,
          body: update.evidence,
          dueAt: value.dueAt ? new Date(value.dueAt) : addDays(new Date(), 3),
          sourceType: update.sourceType,
          sourceId: update.sourceId,
        },
      });
    } else if (update.type === "GIFT_IDEA" && update.personId) {
      const value = asObject(update.proposedValue) as {
        title?: string;
        rationale?: string;
        priceBand?: string;
        sourceFacts?: string[];
      };
      await tx.giftIdea.create({
        data: {
          userId,
          personId: update.personId,
          title: value.title || update.summary,
          rationale: value.rationale || update.evidence,
          priceBand: value.priceBand,
          sourceFactIds: Array.isArray(value.sourceFacts) ? value.sourceFacts : [],
        },
      });
    } else if (update.personId && update.person) {
      const patch = buildPersonPatchForPendingUpdate({
        current: {
          preferences: update.person.preferences,
          communication: update.person.communication,
          importantFacts: update.person.importantFacts,
          sourceSummary: update.person.sourceSummary,
        },
        fieldPath: update.fieldPath,
        proposedValue: update.proposedValue,
        summary: update.summary,
        evidence: update.evidence,
      });
      await tx.person.update({
        where: { id: update.personId },
        data: patch,
      });
    }

    await tx.auditEvent.create({
      data: {
        userId,
        action: "pending_update.confirmed",
        entityType: "PendingUpdate",
        entityId: update.id,
        metadata: { type: update.type, fieldPath: update.fieldPath },
      },
    });

    return tx.pendingUpdate.update({
      where: { id: update.id },
      data: { status: "CONFIRMED", reviewedAt: new Date() },
    });
  });
}

export async function createReminder({
  userId,
  personId,
  title,
  dueAt,
  body,
}: {
  userId: string;
  personId?: string;
  title: string;
  dueAt: Date;
  body?: string;
}) {
  const ownedPersonId = await requireOwnedPersonId({ userId, personId });

  return prisma.reminder.create({
    data: {
      userId,
      personId: ownedPersonId,
      title,
      body,
      dueAt,
      sourceType: "manual",
    },
  });
}

export async function createGiftIdea({
  userId,
  personId,
  title,
  rationale,
  priceBand,
}: {
  userId: string;
  personId: string;
  title: string;
  rationale: string;
  priceBand?: string;
}) {
  const ownedPersonId = await requireOwnedPersonId({ userId, personId });
  if (!ownedPersonId) {
    throw publicApiError("Person was not found", 404);
  }

  return prisma.giftIdea.create({
    data: {
      userId,
      personId: ownedPersonId,
      title,
      rationale,
      priceBand,
    },
  });
}

export async function deletePersonForUser(userId: string, personId: string) {
  const person = await prisma.person.findFirst({
    where: { id: personId, userId },
  });

  if (!person) {
    throw publicApiError("Person was not found", 404);
  }

  await prisma.auditEvent.create({
    data: {
      userId,
      action: "person.deleted",
      entityType: "Person",
      entityId: personId,
    },
  });

  return prisma.person.delete({ where: { id: personId } });
}

async function findOrCreatePerson(userId: string, displayName: string) {
  const existing = await prisma.person.findFirst({
    where: {
      userId,
      displayName: {
        equals: displayName,
        mode: "insensitive",
      },
    },
  });

  if (existing) return existing;

  return prisma.person.create({
    data: {
      userId,
      displayName,
      relationLabel: "朋友",
      groupLabel: "朋友",
    },
  });
}

function initialsFor(name: string) {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

function preferenceField(value: Prisma.JsonValue, key: string): string {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return "Not set";
  }

  const field = (value as Record<string, unknown>)[key];
  if (Array.isArray(field)) {
    const joined = field.filter((item): item is string => typeof item === "string").join(", ");
    return joined || "Not set";
  }

  return typeof field === "string" && field.trim() ? field : "Not set";
}

function classifyReminderType(title: string): DashboardData["reminders"][number]["type"] {
  const normalized = title.toLowerCase();
  if (normalized.includes("birthday") || title.includes("生日")) return "birthday";
  if (
    /考试|面试|搬家|毕业|旅行|入职|换工作|exam|interview|travel|move|graduate|job/.test(
      normalized,
    )
  ) {
    return "life_event";
  }
  return "reminder";
}

function summarizeTitle(text: string) {
  return text.length > 48 ? `${text.slice(0, 45)}...` : text;
}

function toPrismaJson(value: unknown): Prisma.InputJsonValue {
  return JSON.parse(JSON.stringify(value)) as Prisma.InputJsonValue;
}

export function buildPersonPatchForPendingUpdate({
  current,
  fieldPath,
  proposedValue,
  summary,
  evidence,
}: {
  current: {
    preferences: unknown;
    communication: unknown;
    importantFacts: unknown;
    sourceSummary?: string | null;
  };
  fieldPath: string;
  proposedValue: unknown;
  summary: string;
  evidence: string;
}): {
  preferences: Prisma.InputJsonValue;
  communication: Prisma.InputJsonValue;
  importantFacts: Prisma.InputJsonValue;
  sourceSummary: string;
} {
  const preferences = asObject(current.preferences);
  const communication = asObject(current.communication);
  const [namespace, ...path] = fieldPath.split(".").filter(Boolean);

  if (namespace === "preferences" && path.length) {
    applyJsonPath(preferences, path, proposedValue);
  } else if (namespace === "communication" && path.length) {
    applyJsonPath(communication, path, proposedValue);
  } else if (fieldPath === "importantFacts") {
    const facts = toStringArray(proposedValue);
    return {
      preferences: toInputJson(preferences),
      communication: toInputJson(communication),
      importantFacts: toInputJson(appendUniqueStrings(current.importantFacts, [
        ...facts,
        summary,
        evidence,
      ])),
      sourceSummary: summary,
    };
  }

  return {
    preferences: toInputJson(preferences),
    communication: toInputJson(communication),
    importantFacts: toInputJson(appendUniqueStrings(current.importantFacts, [
      summary,
      evidence,
    ])),
    sourceSummary: summary,
  };
}

function applyJsonPath(target: Record<string, unknown>, path: string[], value: unknown) {
  const [head, ...rest] = path;
  if (!head) return;

  if (!rest.length) {
    target[head] = mergeJsonValues(target[head], value);
    return;
  }

  const next = asObject(target[head]);
  target[head] = next;
  applyJsonPath(next, rest, value);
}

function mergeJsonValues(existing: unknown, incoming: unknown): unknown {
  if (Array.isArray(existing)) {
    return appendUniqueValues(existing, Array.isArray(incoming) ? incoming : [incoming]);
  }

  if (Array.isArray(incoming)) {
    return appendUniqueValues([], incoming);
  }

  if (isPlainRecord(existing) && isPlainRecord(incoming)) {
    return Object.entries(incoming).reduce<Record<string, unknown>>(
      (merged, [key, value]) => ({
        ...merged,
        [key]: mergeJsonValues(merged[key], value),
      }),
      { ...existing },
    );
  }

  return incoming ?? existing ?? null;
}

function asObject(value: unknown): Record<string, unknown> {
  return isPlainRecord(value) ? { ...value } : {};
}

function isPlainRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function appendUniqueStrings(existing: unknown, incoming: string[]) {
  return appendUniqueValues(
    toStringArray(existing),
    incoming.map((item) => item.trim()).filter(Boolean),
  );
}

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string" && Boolean(item.trim()));
}

function appendUniqueValues(existing: unknown[], incoming: unknown[]) {
  const seen = new Set(existing.map(stableJsonKey));
  const next = [...existing];

  for (const item of incoming) {
    const key = stableJsonKey(item);
    if (!seen.has(key)) {
      seen.add(key);
      next.push(item);
    }
  }

  return next;
}

function stableJsonKey(value: unknown) {
  return JSON.stringify(value);
}

function toInputJson(value: unknown): Prisma.InputJsonValue {
  return JSON.parse(JSON.stringify(value ?? null)) as Prisma.InputJsonValue;
}
