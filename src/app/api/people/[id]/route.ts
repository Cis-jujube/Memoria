import { del } from "@vercel/blob";

import { handleApiError, jsonOk } from "@/lib/api";
import { deletePersonForUser } from "@/lib/friend-memory";
import { prisma } from "@/lib/db";
import { requireCurrentUser } from "@/lib/session";

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const user = await requireCurrentUser();
    const { id } = await params;
    const files = await prisma.uploadedFile.findMany({
      where: { userId: user.id, personId: id },
      select: { blobUrl: true },
    });
    await deletePersonForUser(user.id, id);

    await Promise.allSettled(
      files.map((file) => del(file.blobUrl).catch(() => undefined)),
    );

    return jsonOk({ deleted: true });
  } catch (error) {
    return handleApiError(error);
  }
}
