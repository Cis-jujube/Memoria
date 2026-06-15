import sgMail from "@sendgrid/mail";

import { handleApiError, jsonError, jsonOk } from "@/lib/api";
import { formatReminderEmail } from "@/lib/reminders";
import { prisma } from "@/lib/db";
import { requireEnv, runtimeFlags } from "@/lib/env";

export async function POST(request: Request) {
  try {
    const expected = requireEnv("CRON_SECRET");
    const provided = request.headers
      .get("authorization")
      ?.replace(/^Bearer\s+/i, "");

    if (!provided || provided !== expected) {
      return jsonError("Unauthorized", 401);
    }

    if (!runtimeFlags.hasSendGridKey()) {
      return jsonError("SENDGRID_API_KEY is not configured", 503);
    }

    sgMail.setApiKey(requireEnv("SENDGRID_API_KEY"));
    const from = requireEnv("SENDGRID_FROM_EMAIL");
    const now = new Date();
    const earliest = new Date(now.getTime() - 60 * 60 * 1000);
    const reminders = await prisma.reminder.findMany({
      where: {
        status: "ACTIVE",
        emailSentAt: null,
        dueAt: { gte: earliest, lte: now },
      },
      include: { user: true, person: true },
      take: 100,
    });

    let sent = 0;
    for (const reminder of reminders) {
      if (!reminder.user.email) continue;
      const email = formatReminderEmail({
        title: reminder.title,
        personName: reminder.person?.displayName,
        dueAt: reminder.dueAt,
        body: reminder.body,
      });

      await sgMail.send({
        to: reminder.user.email,
        from,
        subject: email.subject,
        text: email.text,
      });

      await prisma.reminder.update({
        where: { id: reminder.id },
        data: { emailSentAt: new Date(), status: "SENT" },
      });
      sent += 1;
    }

    return jsonOk({ scanned: reminders.length, sent });
  } catch (error) {
    return handleApiError(error);
  }
}

export const GET = POST;
