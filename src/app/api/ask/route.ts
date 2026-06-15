import { z } from "zod";

import { handleApiError, jsonOk } from "@/lib/api";
import { prisma } from "@/lib/db";
import { requireCurrentUser } from "@/lib/session";

const askSchema = z.object({
  query: z.string().trim().min(2).max(500),
});

export async function POST(request: Request) {
  try {
    const user = await requireCurrentUser();
    const { query } = askSchema.parse(await request.json());
    const [people, memories] = await Promise.all([
      prisma.person.findMany({
        where: {
          userId: user.id,
          OR: [
            { displayName: { contains: query, mode: "insensitive" } },
            { sourceSummary: { contains: query, mode: "insensitive" } },
          ],
        },
        take: 5,
      }),
      prisma.memory.findMany({
        where: {
          userId: user.id,
          OR: [
            { title: { contains: query, mode: "insensitive" } },
            { body: { contains: query, mode: "insensitive" } },
          ],
        },
        take: 5,
        orderBy: { createdAt: "desc" },
      }),
    ]);

    const answer =
      people.length || memories.length
        ? `I found ${people.length} people and ${memories.length} memories that match "${query}".`
        : `No saved people or memories matched "${query}" yet.`;

    return jsonOk({
      answer,
      citations: [
        ...people.map((person) => ({
          type: "person",
          id: person.id,
          label: person.displayName,
        })),
        ...memories.map((memory) => ({
          type: "memory",
          id: memory.id,
          label: memory.title,
        })),
      ],
    });
  } catch (error) {
    return handleApiError(error);
  }
}
