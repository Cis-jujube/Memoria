import { z } from "zod";

import { handleApiError, jsonOk, publicApiError } from "@/lib/api";
import { prisma } from "@/lib/db";
import { requireCurrentUser } from "@/lib/session";

const updateGroupSchema = z.object({
  label: z.string().trim().min(1).max(60).optional(),
  color: z
    .string()
    .trim()
    .regex(/^#[0-9a-f]{6}$/i)
    .optional(),
  description: z.string().trim().max(240).nullable().optional(),
  sortOrder: z.number().int().min(0).max(999).optional(),
});

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const user = await requireCurrentUser();
    const { id } = await params;
    const body = updateGroupSchema.parse(await request.json());
    await requireOwnedGroup(user.id, id);

    if (body.label) {
      const existing = await prisma.contactGroup.findUnique({
        where: { userId_label: { userId: user.id, label: body.label } },
        select: { id: true },
      });
      if (existing && existing.id !== id) {
        throw publicApiError("这个分组名称已经被用了。", 409);
      }
    }

    const group = await prisma.contactGroup.update({
      where: { id },
      data: {
        label: body.label,
        color: body.color,
        description: body.description,
        sortOrder: body.sortOrder,
      },
      include: { _count: { select: { members: true } } },
    });

    return jsonOk({
      group: {
        id: group.id,
        label: group.label,
        color: group.color,
        description: group.description || "",
        sortOrder: group.sortOrder,
        memberCount: group._count.members,
      },
    });
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
    const url = new URL(request.url);
    const mergeIntoGroupId = url.searchParams.get("mergeInto");
    await requireOwnedGroup(user.id, id);

    if (mergeIntoGroupId) {
      if (mergeIntoGroupId === id) {
        throw publicApiError("不能把分组合并到它自己。", 422);
      }
      await requireOwnedGroup(user.id, mergeIntoGroupId);
      const memberships = await prisma.personGroup.findMany({
        where: { userId: user.id, groupId: id },
        select: { personId: true },
      });

      await prisma.$transaction([
        ...memberships.map((membership) =>
          prisma.personGroup.upsert({
            where: {
              personId_groupId: {
                personId: membership.personId,
                groupId: mergeIntoGroupId,
              },
            },
            create: {
              userId: user.id,
              personId: membership.personId,
              groupId: mergeIntoGroupId,
            },
            update: {},
          }),
        ),
        prisma.contactGroup.delete({ where: { id } }),
        prisma.auditEvent.create({
          data: {
            userId: user.id,
            action: "group.deleted",
            entityType: "ContactGroup",
            entityId: id,
            metadata: { mergeIntoGroupId },
          },
        }),
      ]);
    } else {
      await prisma.$transaction([
        prisma.contactGroup.delete({ where: { id } }),
        prisma.auditEvent.create({
          data: {
            userId: user.id,
            action: "group.deleted",
            entityType: "ContactGroup",
            entityId: id,
          },
        }),
      ]);
    }

    return jsonOk({ deleted: true });
  } catch (error) {
    return handleApiError(error);
  }
}

async function requireOwnedGroup(userId: string, id: string) {
  const group = await prisma.contactGroup.findFirst({
    where: { id, userId },
    select: { id: true },
  });

  if (!group) {
    throw publicApiError("分组不存在，或者不属于当前账号。", 404);
  }
}
