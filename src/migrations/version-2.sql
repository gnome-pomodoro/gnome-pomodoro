CREATE TABLE "sessions" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "start-time"            INTEGER NOT NULL UNIQUE,  -- Unix timestamp in microseconds, UTC
    "end-time"              INTEGER NOT NULL,         -- Unix timestamp in microseconds, UTC
    CHECK ("end-time" >= "start-time" OR "end-time" < 0)
);
CREATE INDEX "sessions-start-time" ON "sessions" ("start-time");

CREATE TABLE "timeblocks" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "session-id"            INTEGER NOT NULL,
    "start-time"            INTEGER NOT NULL UNIQUE,  -- Unix timestamp in microseconds, UTC
    "end-time"              INTEGER NOT NULL,         -- Unix timestamp in microseconds, UTC
    "state"                 TEXT NOT NULL,
    "status"                TEXT NOT NULL,
    "intended-duration"     INTEGER NOT NULL,         -- in microseconds
    FOREIGN KEY ("session-id") REFERENCES "sessions" ("id") ON DELETE CASCADE,
    CHECK ("end-time" >= "start-time" OR "end-time" < 0)
);
CREATE INDEX "time-blocks-session-id" ON "timeblocks" ("session-id");

CREATE TABLE "gaps" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "start-time"            INTEGER NOT NULL UNIQUE,  -- Unix timestamp in microseconds, UTC
    "end-time"              INTEGER NOT NULL,         -- Unix timestamp in microseconds, UTC
    "flags"                 TEXT NOT NULL,
    "time-block-id"         INTEGER NOT NULL,         -- parent
    FOREIGN KEY ("time-block-id") REFERENCES "timeblocks" ("id") ON DELETE CASCADE,
    CHECK ("end-time" >= "start-time" OR "end-time" < 0)
);
CREATE INDEX "gaps-time-block-id" ON "gaps" ("time-block-id");

CREATE TABLE "timezones" (
    -- Extra `id` column is needed for Gom. We could just use `time` as the
    -- primary key, but Gom would override given values.
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "time"                  INTEGER NOT NULL UNIQUE,  -- Unix timestamp in microseconds, UTC
    "identifier"            TEXT NOT NULL
);

CREATE TABLE "stats" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "time"                  INTEGER NOT NULL,     -- Unix timestamp in microseconds, UTC
    "date"                  DATE NOT NULL,        -- date adjusted for virtual midnight, local
    "offset"                INTEGER NOT NULL,     -- time of day in microseconds, local
    "duration"              INTEGER DEFAULT 0,    -- in microseconds
    "category"              TEXT NOT NULL,
    "source-id"             INTEGER DEFAULT 0
);
CREATE INDEX "stats-time" ON "stats" ("time");
CREATE INDEX "stats-date" ON "stats" ("date");
CREATE INDEX "stats-category-source-id" ON "stats" (
    "category",
    "source-id"
) WHERE "source-id" != 0;

CREATE TABLE "aggregatedstats" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "date"                  DATE NOT NULL,        -- date adjusted for virtual midnight
    "category"              TEXT NOT NULL,
    "duration"              INTEGER DEFAULT 0,    -- in microseconds
    "count"                 INTEGER DEFAULT 1
);
CREATE INDEX "aggregated-stats-date" ON "aggregatedstats" ("date");
CREATE UNIQUE INDEX "aggregated-stats-date-category" ON "aggregatedstats" (
    "date",
    "category"
);

CREATE TRIGGER "stats-insert" AFTER INSERT ON "stats" FOR EACH ROW
    BEGIN
        INSERT INTO "aggregatedstats" (
                "date",
                "category",
                "duration",
                "count"
            )
            VALUES (
                NEW."date",
                NEW."category",
                NEW."duration",
                CASE
                    WHEN NEW."source-id" = 0 THEN 1
                    WHEN NOT EXISTS (
                        SELECT 1 FROM "stats"
                        WHERE
                            "category" = NEW."category" AND
                            "source-id" = NEW."source-id" AND
                            "id" <> NEW."id"
                    ) THEN 1
                    ELSE 0
                END
            )
            ON CONFLICT("date","category") DO UPDATE SET
                "duration" = "duration" + excluded."duration",
                "count" = "count" + excluded."count";
    END;

CREATE TRIGGER "stats-update" AFTER UPDATE ON "stats" FOR EACH ROW
    BEGIN
        UPDATE "aggregatedstats"
            SET
                "duration" = "duration" + NEW."duration"
            WHERE
                "date" = NEW."date" AND
                "category" = NEW."category";

        INSERT INTO "aggregatedstats" (
                "date",
                "category",
                "duration"
            )
            SELECT
                NEW."date",
                NEW."category",
                NEW."duration"
            WHERE
                changes() = 0;

        UPDATE "aggregatedstats"
            SET
                "duration" = "duration" - OLD."duration"
            WHERE
                "date" = OLD."date" AND
                "category" = OLD."category";
    END;

CREATE TRIGGER "stats-delete" AFTER DELETE ON "stats" FOR EACH ROW
    BEGIN
        UPDATE "aggregatedstats"
            SET
                "duration" = "duration" - OLD."duration",
                "count" = "count" - CASE
                    WHEN OLD."source-id" = 0 THEN 1
                    WHEN NOT EXISTS (
                        SELECT 1 FROM "stats"
                        WHERE
                            "category" = OLD."category" AND
                            "source-id" = OLD."source-id"
                    ) THEN 1
                    ELSE 0
                END
            WHERE
                "date" = OLD."date" AND
                "category" = OLD."category";
    END;
