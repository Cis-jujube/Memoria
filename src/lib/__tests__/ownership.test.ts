import { describe, expect, it } from "vitest";

import { assertOwnedByUser, filterOwnedByUser } from "@/lib/ownership";
import { requireOwnedPersonId } from "@/lib/people";

describe("ownership guards", () => {
  it("filters records by the active user id", () => {
    const records = [
      { id: "a", userId: "u1", name: "Alex" },
      { id: "b", userId: "u2", name: "May" },
      { id: "c", userId: "u1", name: "Jason" },
    ];

    expect(filterOwnedByUser(records, "u1")).toEqual([
      { id: "a", userId: "u1", name: "Alex" },
      { id: "c", userId: "u1", name: "Jason" },
    ]);
  });

  it("throws when a record belongs to another user", () => {
    expect(() =>
      assertOwnedByUser({ id: "b", userId: "u2" }, "u1", "Person"),
    ).toThrow("Person does not belong to the active user");
  });

  it("returns a person id only when the lookup is scoped to the active user", async () => {
    const personId = await requireOwnedPersonId({
      userId: "u1",
      personId: "p1",
      lookup: async (userId, id) =>
        userId === "u1" && id === "p1" ? { id } : null,
    });

    await expect(
      requireOwnedPersonId({
        userId: "u2",
        personId: "p1",
        lookup: async () => null,
      }),
    ).rejects.toThrow("Person was not found");

    expect(personId).toBe("p1");
  });
});
