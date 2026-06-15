import { z } from "zod";

import { handleApiError, jsonOk, publicApiError } from "@/lib/api";
import { prisma } from "@/lib/db";
import { requireOwnedPersonId } from "@/lib/people";
import { requireCurrentUser } from "@/lib/session";

const membershipSchema = z.object({
  groupId: z.string().trim().min(1),
});

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const user = await requireCurrentUser();
    const { id } = await params;
    const body = membershipSchema.parse(await request.json());
    const personId = await requireOwnedPersonId({ userId: user.id, personId: id });
    await requireOwnedGroup(user.id, body.groupId);

    const membership = await prisma.personGroup.upsert({
      where: {
        personId_groupId: {
          personId: personId!,
          groupId: body.groupId,
        },
      },
      create: {
        userId: user.id,
        personId: personId!,
        groupId: body.groupId,
      },
      update: {},
    });

    return jsonOk({ membership }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const user = await requireCurrentUser();
    const { id } = await params;
    const body = membershipSchema.parse(await request.json());
    const personId = await requireOwnedPersonId({ userId: user.id, personId: id });
    await prisma.personGroup.deleteMany({
      where: {
        userId: user.id,
        personId,
        groupId: body.groupId,
      },
    });

    return jsonOk({ removed: true });
  } catch (error) {
    return handleApiError(error);
  }
}

async function requireOwnedGroup(userId: string, groupId: string) {
  const group = await prisma.contactGroup.findFirst({
    where: { id: groupId, userId },
    select: { id: true },
  });

  if (!group) {
    throw publicApiError("分组不存在，或者不属于当前账号。", 404);
  }
}
