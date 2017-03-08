CREATE TABLE "aggregated_entries" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "state-name" TEXT NOT NULL,
    "state-duration" INTEGER,
    "date" INTEGER,
    "elapsed" INTEGER
);

CREATE TABLE "entries" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "state-name" TEXT NOT NULL,
    "state-duration" INTEGER,
    "timestamp" INTEGER,
    "elapsed" INTEGER
);

CREATE UNIQUE INDEX "entries_unique" ON "entries" ("timestamp", "state-name");
CREATE UNIQUE INDEX "aggregated_entries_unique" ON "entries" ("date", "state-name");
