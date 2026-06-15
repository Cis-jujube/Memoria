import { z } from "zod";

import { handleApiError, jsonOk, publicApiError } from "@/lib/api";
import { prisma } from "@/lib/db";
import { requireCurrentUser } from "@/lib/session";

const groupSchema = z.object({
  label: z.string().trim().min(1).max(60),
  color: z
    .string()
    .trim()
    .regex(/^#[0-9a-f]{6}$/i)
    .default("#184f3c"),
  description: z.string().trim().max(240).optional(),
  sortOrder: z.number().int().min(0).max(999).optional(),
});

export async function GET() {
  try {
    const user = await requireCurrentUser();
    const groups = await prisma.contactGroup.findMany({
      where: { userId: user.id },
      orderBy: [{ sortOrder: "asc" }, { label: "asc" }],
      include: { _count: { select: { members: true } } },
    });

    return jsonOk({
      groups: groups.map((group) => ({
        id: group.id,
        label: group.label,
        color: group.color,
        description: group.description || "",
        sortOrder: group.sortOrder,
        memberCount: group._count.members,
      })),
    });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: Request) {
  try {
    const user = await requireCurrentUser();
    const body = groupSchema.parse(await request.json());
    const existing = await prisma.contactGroup.findUnique({
      where: { userId_label: { userId: user.id, label: body.label } },
      select: { id: true },
    });

    if (existing) {
      throw publicApiError("这个分组已经存在了。", 409);
    }

    const group = await prisma.contactGroup.create({
      data: {
        userId: user.id,
        label: body.label,
        color: body.color,
        description: body.description,
        sortOrder: body.sortOrder ?? 0,
      },
      include: { _count: { select: { members: true } } },
    });

    await prisma.auditEvent.create({
      data: {
        userId: user.id,
        action: "group.created",
        entityType: "ContactGroup",
        entityId: group.id,
        metadata: { label: group.label },
      },
    });

    return jsonOk(
      {
        group: {
          id: group.id,
          label: group.label,
          color: group.color,
          description: group.description || "",
          sortOrder: group.sortOrder,
          memberCount: group._count.members,
        },
      },
      { status: 201 },
    );
  } catch (error) {
    return handleApiError(error);
  }
}
