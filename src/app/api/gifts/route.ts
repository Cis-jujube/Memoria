import { z } from "zod";

import { buildGiftCitation, rankGiftIdeas } from "@/lib/gifts";
import { handleApiError, jsonOk } from "@/lib/api";
import { createGiftIdea } from "@/lib/friend-memory";
import { prisma } from "@/lib/db";
import { requireCurrentUser } from "@/lib/session";

const giftSchema = z.object({
  personId: z.string().min(1),
  title: z.string().trim().min(1).max(160),
  rationale: z.string().trim().min(1).max(1000),
  priceBand: z.string().trim().max(20).optional(),
});

export async function GET() {
  try {
    const user = await requireCurrentUser();
    const gifts = await prisma.giftIdea.findMany({
      where: { userId: user.id },
      include: { person: true },
      orderBy: { updatedAt: "desc" },
      take: 20,
    });

    const ranked = rankGiftIdeas(gifts).map((gift) => ({
      ...gift,
      citation: buildGiftCitation({
        facts: gift.sourceFactIds,
        memories: [gift.rationale],
      }),
    }));

    return jsonOk({ gifts: ranked });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: Request) {
  try {
    const user = await requireCurrentUser();
    const body = giftSchema.parse(await request.json());
    const gift = await createGiftIdea({ userId: user.id, ...body });

    return jsonOk({ gift }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}
