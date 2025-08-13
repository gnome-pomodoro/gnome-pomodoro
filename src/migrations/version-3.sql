-- Populate new "stats" table from legacy "entries" table and drop legacy tables
-- Notes:
--   - Units conversion: legacy durations are in seconds -> convert to microseconds.
--   - Previously we made a single entry for the whole pomodoro / break, now we make an entry for an segment.
--   - Legacy "entries" table is dropped.
--   - The state-duration column is not used in the new "stats" table.
--   - We loose some timezone information.

WITH pre AS (
    SELECT
        COALESCE(
            CAST(strftime('%s', e."datetime-string") AS INTEGER),
            CAST(strftime('%s', replace(replace(substr(e."datetime-string", 1, 19), 'T', ' '), 'Z', '')) AS INTEGER),
            CAST(strftime('%s', e."datetime-local-string") AS INTEGER),
            CAST(strftime('%s', replace(replace(substr(e."datetime-local-string", 1, 19), 'T', ' '), 'Z', '')) AS INTEGER)
        ) AS "epoch-seconds",
        COALESCE(
            replace(replace(substr(e."datetime-local-string", 1, 19), 'T', ' '), 'Z', ''),
            replace(replace(substr(e."datetime-string", 1, 19), 'T', ' '), 'Z', '')
        ) AS "local-base",
        CAST(COALESCE(e."elapsed", 0) AS INTEGER) AS "elapsed-seconds",
        e."state-name" AS "state-name"
    FROM "entries" e
    WHERE e."state-name" IN ('pomodoro', 'break', 'short-break', 'long-break')
), parts AS (
    SELECT
        "epoch-seconds",
        "elapsed-seconds",
        "state-name",
        "local-base",
        CAST(strftime('%H', "local-base") AS INTEGER) AS "hour",
        CAST(strftime('%M', "local-base") AS INTEGER) AS "minute",
        CAST(strftime('%S', "local-base") AS INTEGER) AS "second"
    FROM pre
)
INSERT OR IGNORE INTO "stats" (
    "time",
    "date",
    "offset",
    "duration",
    "category",
    "source-id"
)
SELECT
    "epoch-seconds" * 1000000 AS "time",
    CASE
        WHEN "hour" < 4 THEN date("local-base", '-1 day')
        ELSE date("local-base")
    END AS "date",
    (
        "hour" * 3600000000 +
        "minute" * 60000000 +
        "second" * 1000000 +
        CASE WHEN "hour" < 4 THEN 24 * 3600000000 ELSE 0 END
    ) AS "offset",
    "elapsed-seconds" * 1000000 AS "duration",
    CASE "state-name"
        WHEN 'pomodoro' THEN 'pomodoro'
        WHEN 'break' THEN 'break'
        WHEN 'short-break' THEN 'break'
        WHEN 'long-break' THEN 'break'
        ELSE NULL
    END AS "category",
    0 AS "source-id"
FROM parts;

DROP TRIGGER "entries-insert";
DROP TRIGGER "entries-update";
DROP TRIGGER "entries-delete";

DROP TABLE "aggregated-entries";
DROP TABLE "entries";
