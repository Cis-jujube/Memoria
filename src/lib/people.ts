import { publicApiError } from "@/lib/api";
import { prisma } from "@/lib/db";

export type OwnedPersonLookup = (
  userId: string,
  personId: string,
) => Promise<{ id: string } | null>;

export async function requireOwnedPersonId({
  userId,
  personId,
  lookup = findOwnedPerson,
}: {
  userId: string;
  personId?: string | null;
  lookup?: OwnedPersonLookup;
}) {
  const normalized = personId?.trim();

  if (!normalized) {
    return undefined;
  }

  const person = await lookup(userId, normalized);

  if (!person) {
    throw publicApiError("Person was not found", 404);
  }

  return person.id;
}

async function findOwnedPerson(userId: string, personId: string) {
  return prisma.person.findFirst({
    where: { id: personId, userId },
    select: { id: true },
  });
}
