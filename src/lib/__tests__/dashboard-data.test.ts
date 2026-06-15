import { beforeEach, describe, expect, it, vi } from "vitest";

const dbMocks = vi.hoisted(() => ({
  prisma: {
    person: {
      count: vi.fn(),
      findMany: vi.fn(),
    },
    contactGroup: {
      findMany: vi.fn(),
    },
    pendingUpdate: {
      count: vi.fn(),
      findMany: vi.fn(),
    },
    reminder: {
      count: vi.fn(),
      findMany: vi.fn(),
    },
    giftIdea: {
      findMany: vi.fn(),
    },
    uploadedFile: {
      count: vi.fn(),
      findMany: vi.fn(),
    },
  },
}));

vi.mock("@/lib/db", () => dbMocks);
vi.mock("@/lib/relationship-intelligence", () => ({
  enrichDashboardData: (data: unknown) => data,
}));

describe("getDashboardData", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("uses count queries for dashboard stats instead of limited preview arrays", async () => {
    dbMocks.prisma.person.findMany.mockResolvedValueOnce([personFixture()]);
    dbMocks.prisma.contactGroup.findMany.mockResolvedValueOnce([]);
    dbMocks.prisma.pendingUpdate.findMany.mockResolvedValueOnce([]);
    dbMocks.prisma.reminder.findMany.mockResolvedValueOnce([]);
    dbMocks.prisma.giftIdea.findMany.mockResolvedValueOnce([]);
    dbMocks.prisma.uploadedFile.findMany.mockResolvedValueOnce([]);
    dbMocks.prisma.pendingUpdate.count.mockResolvedValueOnce(14);
    dbMocks.prisma.reminder.count.mockResolvedValueOnce(11);
    dbMocks.prisma.person.count.mockResolvedValueOnce(9);
    dbMocks.prisma.uploadedFile.count.mockResolvedValueOnce(3);

    const { getDashboardData } = await import("@/lib/friend-memory");
    const data = await getDashboardData("user_1", "Me");

    expect(data.stats).toMatchObject({
      inbox: 14,
      reminders: 11,
      birthdays: 9,
      files: 3,
    });
    expect(dbMocks.prisma.pendingUpdate.count).toHaveBeenCalledWith({
      where: { userId: "user_1", status: "PENDING" },
    });
    expect(dbMocks.prisma.uploadedFile.count).toHaveBeenCalledWith({
      where: { userId: "user_1", status: "PROCESSING" },
    });
  });
});

function personFixture() {
  return {
    id: "person_1",
    displayName: "Alex Chen",
    relationLabel: "朋友",
    groupLabel: "朋友",
    groups: [],
    location: null,
    birthdayMonth: null,
    birthdayDay: null,
    communication: {},
    preferences: {},
    sourceSummary: null,
  };
}
