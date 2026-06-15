-- CreateTable
CREATE TABLE "ContactGroup" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "color" TEXT NOT NULL DEFAULT '#184f3c',
    "description" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ContactGroup_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PersonGroup" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "personId" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PersonGroup_pkey" PRIMARY KEY ("id")
);

-- Seed groups from the legacy Person.groupLabel field.
INSERT INTO "ContactGroup" ("id", "userId", "label", "color", "description", "sortOrder", "createdAt", "updatedAt")
SELECT
    concat('cg_', md5("userId" || ':' || "groupLabel")),
    "userId",
    "groupLabel",
    '#184f3c',
    'Migrated from legacy group label.',
    row_number() OVER (PARTITION BY "userId" ORDER BY "groupLabel") - 1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM (
    SELECT DISTINCT "userId", "groupLabel"
    FROM "Person"
    WHERE "groupLabel" IS NOT NULL AND btrim("groupLabel") <> ''
) legacy_groups
ON CONFLICT DO NOTHING;

INSERT INTO "PersonGroup" ("id", "userId", "personId", "groupId", "createdAt")
SELECT
    concat('pg_', md5(person."id" || ':' || contact_group."id")),
    person."userId",
    person."id",
    contact_group."id",
    CURRENT_TIMESTAMP
FROM "Person" person
JOIN "ContactGroup" contact_group
  ON contact_group."userId" = person."userId"
 AND contact_group."label" = person."groupLabel"
WHERE person."groupLabel" IS NOT NULL AND btrim(person."groupLabel") <> ''
ON CONFLICT DO NOTHING;

-- CreateIndex
CREATE UNIQUE INDEX "ContactGroup_userId_label_key" ON "ContactGroup"("userId", "label");

-- CreateIndex
CREATE INDEX "ContactGroup_userId_sortOrder_idx" ON "ContactGroup"("userId", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "PersonGroup_personId_groupId_key" ON "PersonGroup"("personId", "groupId");

-- CreateIndex
CREATE INDEX "PersonGroup_userId_groupId_idx" ON "PersonGroup"("userId", "groupId");

-- CreateIndex
CREATE INDEX "PersonGroup_userId_personId_idx" ON "PersonGroup"("userId", "personId");

-- AddForeignKey
ALTER TABLE "ContactGroup" ADD CONSTRAINT "ContactGroup_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PersonGroup" ADD CONSTRAINT "PersonGroup_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PersonGroup" ADD CONSTRAINT "PersonGroup_personId_fkey" FOREIGN KEY ("personId") REFERENCES "Person"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PersonGroup" ADD CONSTRAINT "PersonGroup_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "ContactGroup"("id") ON DELETE CASCADE ON UPDATE CASCADE;
