-- schema.sql — Undertale encounter cost analysis
-- runs six read-only checks confirming the database loaded correctly
DROP TABLE IF EXISTS free_kills;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS monsters;
DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS exp_to_lv;
DROP TABLE IF EXISTS route_requirements;



-- One row per area. Referenced by monsters, rooms and free_kills.
-- kills_required is 0 for Core: Hotland and Core share one kill counter
-- (both reference flag index 205), so the 40 required kills are recorded
-- once, on Hotland, and route totals don't double-count them.
-- argument3 is that flag index, read from the encounter scripts.

CREATE TABLE route_requirements (
    area                 TEXT PRIMARY KEY,
    area_order           INTEGER,
    kills_required       INTEGER,
    shares_counter_with  TEXT,
    total_rooms          INTEGER,
    grind_rooms          INTEGER,
    argument3            INTEGER
);


-- One row per STAT BLOCK, not per monster name. A monster with two stat
-- blocks (the first Froggit encountered vs. ordinary Froggits) gets two
-- rows separated by `variant`.
-- *_check   = the value the game displays when the player CHECKs
-- *_actual  = the value the combat math actually uses
-- at_check / df_check are REAL because two bosses carry fractional
-- displayed values. exp_on_kill is REAL because one monster's award is
-- an expected value over a random range, and NULL where the monster
-- cannot be killed at all.
-- fixed_turns: a number = the fight lasts that many turns regardless of
-- player stats; 0 = the encounter is skippable with correct routing;
-- NULL = duration is computed from stats.

CREATE TABLE monsters (
    monster_id      INTEGER PRIMARY KEY,
    name            TEXT,
    variant         TEXT,
    area            TEXT,
    hp_check        INTEGER,
    at_check        REAL,
    at_actual       INTEGER,
    df_check        REAL,
    df_actual       INTEGER,
    exp_on_kill     REAL,
    encounter_type  TEXT NOT NULL,   -- 'farmable' | 'fixed' | 'one-time'
    is_boss         INTEGER,
    fixed_turns     INTEGER
);



-- One row per room that can produce a step-based encounter. Rooms with
-- no encounter object are excluded and counted in aggregate on
-- route_requirements (total_rooms vs grind_rooms).

-- Composite primary key: room ids restart per area, so room 9 exists in
-- the Ruins, Waterfall and Hotland. Identity is (room_id, area).

-- first_* = the Create event's values — the first encounter after
--           entering a room. Crossing a room transition resets the step
--           counter, so these apply again on re-entry.
-- base_*  = the Step event's values — every encounter after the first.
-- alt_*   = override values that apply when alt_condition holds. These
--           override the base_* / first_* pair, not the formula.

-- encounter_object is copied verbatim from the game files, including
-- the original author's typos, so each row is traceable to its source.

CREATE TABLE rooms (
    room_id                INTEGER NOT NULL,
    area                   TEXT    NOT NULL,
    internal_room_name     TEXT    NOT NULL,
    encounter_object       TEXT    NOT NULL,
    base_steps             INTEGER,
    random_steps_max       INTEGER,
    first_base_steps       INTEGER,
    first_random_steps     INTEGER,
    alt_base_steps         INTEGER,
    alt_random_steps       INTEGER,
    alt_firstbase_steps    INTEGER,
    alt_firstrandom_steps  INTEGER,
    alt_condition          TEXT,
    alt_applies            INTEGER NOT NULL DEFAULT 0,  -- see below
    encounter_pool         TEXT    NOT NULL,   -- 'random' | 'Jerry' | 'Gyftrot'
    PRIMARY KEY (room_id, area)
);

/* alt_applies records whether a room's alt_condition actually holds on this route, so queries don't have to interpret the condition text:
   Core rooms      1  — LV 12 gate, cleared at LV 17 before arrival
   water6, fire5   1  — room-name conditions; each row IS that room
   water15/16/17   0  — LV 10 gate crossed partway through the area
   all others      0  — no alt values exist
*/


-- Weapons and armor. No prices: every item on this route is found
-- rather than purchased, so there is no purchase decision to model.

CREATE TABLE items (
    item_id     INTEGER PRIMARY KEY,
    name        TEXT,
    type        TEXT    NOT NULL,   -- 'weapon' | 'armor'
    at_bonus    INTEGER NOT NULL,
    df_bonus    INTEGER NOT NULL,
    area_found  TEXT    NOT NULL
);



-- LV thresholds. 'at' and 'df' are the displayed values; the internal
-- values used in combat are 10 higher. exp_to_next is NULL at LV 20.

CREATE TABLE exp_to_lv (
    lv           INTEGER PRIMARY KEY,
    hp           INTEGER,
    at           INTEGER,
    df           INTEGER,
    exp_to_next  INTEGER,
    total_exp    INTEGER
);


-- Encounters that advance the kill counter without any walking cost.
-- room_id is nullable: not every such encounter happens in a room that appears in 'rooms'.

CREATE TABLE free_kills (
    event_id       INTEGER PRIMARY KEY,
    area           TEXT NOT NULL,
    event_name     TEXT,
    kills_yielded  INTEGER,
    monsters       TEXT,
    room_id        INTEGER
);



-- POST-IMPORT DATA SETUP — run these two statements AFTER loading the
-- CSVs, not before. They set 'alt_applies', which the cost model reads
-- to decide whether a room runs at its base or its alt step values.

-- The CORE's five rooms drop to 70/120 steps at LV 12. Undyne the
-- Undying awards 15,000 EXP, which puts the player near LV 17 before
-- Hotland begins, so the threshold is always cleared in practice.
UPDATE rooms SET alt_applies = 1 WHERE area = 'Core';

-- water6 and fire5 carry room-name conditions rather than LV conditions.
-- Each of those rows IS the room named in its own condition, so the
-- override always holds. Both make the room more expensive, not less.
UPDATE rooms SET alt_applies = 1
WHERE internal_room_name IN ('water6', 'fire5');

-- water15/16/17 switch at LV 10. The player reaches Waterfall at roughly
-- LV 8-9 and crosses the threshold partway through the area, or in an
-- unlucky run not at all, so most grinding there happens at the base
-- rate. Left at 0 and stated as an assumption in the README.



-- Verification — run after the two statements above.

-- SELECT 'route_requirements' AS t, COUNT(*) FROM route_requirements
-- UNION ALL SELECT 'monsters',   COUNT(*) FROM monsters
-- UNION ALL SELECT 'rooms',      COUNT(*) FROM rooms
-- UNION ALL SELECT 'items',      COUNT(*) FROM items
-- UNION ALL SELECT 'exp_to_lv',  COUNT(*) FROM exp_to_lv
-- UNION ALL SELECT 'free_kills', COUNT(*) FROM free_kills;

-- Type check: both should return 'integer'. 'text' means an import
-- wizard created its own table instead of using the DDL above.
-- SELECT typeof(base_steps), typeof(random_steps_max) FROM rooms LIMIT 1;
