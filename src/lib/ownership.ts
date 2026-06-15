export type OwnedRecord = {
  id: string;
  userId: string;
};

export function filterOwnedByUser<T extends OwnedRecord>(
  records: T[],
  userId: string,
) {
  return records.filter((record) => record.userId === userId);
}

export function assertOwnedByUser<T extends OwnedRecord>(
  record: T | null | undefined,
  userId: string,
  label = "Record",
): T {
  if (!record) {
    throw new Error(`${label} was not found`);
  }

  if (record.userId !== userId) {
    throw new Error(`${label} does not belong to the active user`);
  }

  return record;
}
