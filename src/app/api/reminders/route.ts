import { z } from "zod";

import { handleApiError, jsonOk } from "@/lib/api";
import { createReminder } from "@/lib/friend-memory";
import { prisma } from "@/lib/db";
import { requireCurrentUser } from "@/lib/session";

const reminderSchema = z.object({
  personId: z.string().trim().min(1).optional(),
  title: z.string().trim().min(1).max(160),
  body: z.string().trim().max(1000).optional(),
  dueAt: z.string().datetime(),
});

export async function GET() {
  try {
    const user = await requireCurrentUser();
    const reminders = await prisma.reminder.findMany({
      where: { userId: user.id, status: "ACTIVE" },
      orderBy: { dueAt: "asc" },
      include: { person: true },
    });

    return jsonOk({ reminders });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: Request) {
  try {
    const user = await requireCurrentUser();
    const body = reminderSchema.parse(await request.json());
    const reminder = await createReminder({
      userId: user.id,
      personId: body.personId,
      title: body.title,
      body: body.body,
      dueAt: new Date(body.dueAt),
    });

    return jsonOk({ reminder }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}
