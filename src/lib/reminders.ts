export type ReminderLike = {
  id?: string;
  status: string;
  dueAt: Date;
  emailSentAt: Date | null;
};

export function isReminderDueForEmail(
  reminder: ReminderLike,
  now = new Date(),
  lookbackMinutes = 60,
) {
  if (reminder.status !== "ACTIVE") return false;
  if (reminder.emailSentAt) return false;

  const dueTime = reminder.dueAt.getTime();
  const nowTime = now.getTime();
  const earliest = nowTime - lookbackMinutes * 60 * 1000;

  return dueTime <= nowTime && dueTime >= earliest;
}

export function findDueReminders<T extends ReminderLike>(
  reminders: T[],
  now = new Date(),
  lookbackMinutes = 60,
) {
  return reminders.filter((reminder) =>
    isReminderDueForEmail(reminder, now, lookbackMinutes),
  );
}

export function formatReminderEmail({
  title,
  personName,
  dueAt,
  body,
}: {
  title: string;
  personName?: string | null;
  dueAt: Date;
  body?: string | null;
}) {
  const subject = personName
    ? `Reminder: ${title} (${personName})`
    : `Reminder: ${title}`;

  const lines = [
    subject,
    "",
    `Due: ${dueAt.toLocaleString("en-US", { timeZone: "UTC" })} UTC`,
  ];

  if (body) lines.push("", body);

  return {
    subject,
    text: lines.join("\n"),
  };
}
