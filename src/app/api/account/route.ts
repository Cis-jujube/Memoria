import { z } from "zod";

import { handleApiError, jsonOk } from "@/lib/api";
import { prisma } from "@/lib/db";
import { requireCurrentUser } from "@/lib/session";

const accountSchema = z.object({
  name: z.string().trim().min(1).max(80),
});

export async function PATCH(request: Request) {
  try {
    const user = await requireCurrentUser();
    const body = accountSchema.parse(await request.json());
    const updated = await prisma.user.update({
      where: { id: user.id },
      data: { name: body.name },
      select: { id: true, name: true, email: true },
    });

    return jsonOk({ user: updated });
  } catch (error) {
    return handleApiError(error);
  }
}
