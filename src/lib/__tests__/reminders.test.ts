import { describe, expect, it } from "vitest";

import { findDueReminders, isReminderDueForEmail } from "@/lib/reminders";

describe("reminder due-window calculation", () => {
  const now = new Date("2026-06-10T12:00:00.000Z");

  it("selects active unsent reminders due within the scan window", () => {
    const reminders = [
      {
        id: "due",
        status: "ACTIVE",
        dueAt: new Date("2026-06-10T11:55:00.000Z"),
        emailSentAt: null,
      },
      {
        id: "future",
        status: "ACTIVE",
        dueAt: new Date("2026-06-10T12:30:00.000Z"),
        emailSentAt: null,
      },
      {
        id: "sent",
        status: "ACTIVE",
        dueAt: new Date("2026-06-10T11:50:00.000Z"),
        emailSentAt: new Date("2026-06-10T11:51:00.000Z"),
      },
      {
        id: "archived",
        status: "ARCHIVED",
        dueAt: new Date("2026-06-10T11:45:00.000Z"),
        emailSentAt: null,
      },
    ];

    expect(findDueReminders(reminders, now).map((item) => item.id)).toEqual([
      "due",
    ]);
  });

  it("treats reminders older than the lookback window as not email-due", () => {
    expect(
      isReminderDueForEmail(
        {
          status: "ACTIVE",
          dueAt: new Date("2026-06-10T10:00:00.000Z"),
          emailSentAt: null,
        },
        now,
      ),
    ).toBe(false);
  });
});
