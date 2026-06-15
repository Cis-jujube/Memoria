import { z } from "zod";

import { handleApiError, jsonOk } from "@/lib/api";
import { reviewPendingUpdate } from "@/lib/friend-memory";
import { requireCurrentUser } from "@/lib/session";

const reviewSchema = z.object({
  action: z.enum(["confirm", "discard"]),
});

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const user = await requireCurrentUser();
    const { id } = await params;
    const body = reviewSchema.parse(await request.json());
    const result = await reviewPendingUpdate({
      userId: user.id,
      updateId: id,
      action: body.action,
    });

    return jsonOk({ id: result.id, status: result.status });
  } catch (error) {
    return handleApiError(error);
  }
}
