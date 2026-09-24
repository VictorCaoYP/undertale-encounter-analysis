-- Q1 — What does a single kill cost, and how does that change across an area?
-- Creates the 'kill_costs' view. Every later query reads from this, so the cost model lives in exactly one place.
-- Grain: one row per (area, room, kill number).

-- Reproduces the game's scr_steps function:
--     steps = (base_steps + random(0..random_steps_max)) * population_factor
--     population_factor = kills_required / (kills_required - kills_done), capped at 8

/* Two things this model gets right that a naive per-area version does not:
  1. Hotland and the CORE share one kill counter (both reference flag
  		index 205), so the sequence is built per COUNTER, not per area.
  2. Some encounter objects swap to cheaper step values once the 
  		player passes an LV threshold. 'alt_applies' records, per room,
      	whether that swap is in effect on this route.
*/

/* Prerequisite: schema.sql has been run, the CSVs imported, and the
 * post-import UPDATE statements at the bottom of schema.sql applied.
*/
DROP VIEW IF EXISTS kill_costs;

CREATE VIEW kill_costs AS
WITH RECURSIVE

-- One row per kill COUNTER rather than per area. MAX() resolves the
-- shared counter: Hotland's 40 wins over the CORE's 0, so 205 gets 40.
counters AS (
    SELECT
        argument3,
        MAX(kills_required) AS kills_required
    FROM route_requirements
    WHERE argument3 IS NOT NULL          -- drops New Home
    GROUP BY argument3
    HAVING MAX(kills_required) > 1
),

-- Expands each counter into one row per individual kill.
kill_seq AS (
    SELECT argument3, kills_required, 0 AS kills_done
    FROM counters

    UNION ALL

    SELECT argument3, kills_required, kills_done + 1
    FROM kill_seq
    WHERE kills_done + 1 < kills_required
),

/* The encounter penalty. At 0 kills it is 1.0; at the halfway point 2.0
 * at the last kill it would be kills_required itself, which the game
 * caps at 8. The * 1.0 forces floating-point division.
*/
pop AS (
    SELECT
        argument3,
        kills_done,
        kills_required,
        MIN(kills_required * 1.0 / (kills_required - kills_done), 8.0) AS pop_factor
    FROM kill_seq
),

/* Attaches each room to the counter its area draws from, and resolves
 * which step values that room actually runs at. step_constant is the
 * expected steps for one encounter before the penalty is applied;
 * random/2.0 is the mean of a uniform roll from 0.
*/
room_counters AS (
    SELECT
        r.*,
        rr.argument3,
        CASE WHEN r.alt_applies = 1
             THEN (r.alt_base_steps + r.alt_random_steps  / 2.0)
             ELSE (r.base_steps     + r.random_steps_max  / 2.0)
        END AS step_constant
    FROM rooms r
    JOIN route_requirements rr ON rr.area = r.area
),

/* Joining on the counter is what puts the CORE's rooms into Hotland's
 * 40-kill sequence. 'area' still reads 'Core', which is what makes the
 * Hotland-vs-CORE comparison possible.
*/

costed AS (
    SELECT
        r.area,
        p.argument3,
        r.room_id,
        r.internal_room_name,
        r.encounter_object,
        r.encounter_pool,
        r.alt_applies,
        r.step_constant,
        p.kills_done,
        p.pop_factor,
        r.step_constant * p.pop_factor AS expected_steps
    FROM pop p
    JOIN room_counters r ON r.argument3 = p.argument3
)

SELECT
    area,
    argument3,
    room_id,
    internal_room_name,
    encounter_object,
    encounter_pool,
    alt_applies,
    step_constant,
    kills_done,
    pop_factor,
    expected_steps,
    SUM(expected_steps) OVER (
        PARTITION BY area, room_id
        ORDER BY kills_done
    ) AS cumulative_steps
FROM costed;


-- Verification

-- 724 rows: Ruins 20x10 + Snowdin 16x6 + Waterfall 18x6 + (Hotland 3 + Core 5 rooms) x 40.
-- SELECT COUNT(*) FROM kill_costs;

-- Five areas, Core included. If Core is missing, the counter join failed.

-- SELECT DISTINCT area FROM kill_costs ORDER BY area;
-- 130. If this returns 530, the post-import UPDATE statements in schema.sql have not been run and the CORE is being charged its base rate instead of the LV-gated one.

-- SELECT DISTINCT step_constant FROM kill_costs WHERE area = 'Core';
-- Hotland and Core should both show 40 kills — either area can host the whole shared pool, which is the premise of the Q3 comparison.

-- SELECT area, COUNT(DISTINCT room_id) AS rooms, COUNT(DISTINCT kills_done) AS kills
-- FROM kill_costs GROUP BY area ORDER BY area;