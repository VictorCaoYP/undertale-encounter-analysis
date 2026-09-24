-- Q3 — Which room should you grind in?

-- Reads kill_costs. Each room's total is the cost of clearing that
-- counter's entire kill requirement without ever leaving the room.
-- Ranked per COUNTER rather than per area, because Hotland and the CORE
-- draw from one shared pool of 40 kills — so their rooms compete with
-- each other directly. That comparison is the point of the query.

SELECT
    argument3 AS counter_flag,
    area,
    internal_room_name,
    encounter_object,
    encounter_pool,
    alt_applies,
    step_constant,
    ROUND(MAX(cumulative_steps) AS total_steps,
    RANK() OVER (
        PARTITION BY argument3
        ORDER BY MAX(cumulative_steps)
    ) AS rank_in_counter,
    ROUND(
    	MAX(cumulative_steps) / MIN(MAX(cumulative_steps)) 
    	OVER (PARTITION BY argument3), 2
    ) AS times_worse_than_best
FROM kill_costs
GROUP BY area, room_id
ORDER BY argument3, rank_in_counter;


-- Expected shape of the result (rooms sharing an encounter object have identical totals and therefore tie in the ranking):

--   Ruins            ruins15B/C/D     170      9,852   <- best
--                    ruins10          365     21,153   <- worst, 2.1x

--   Snowdin          tundra3/4/6      280     12,906   <- best
--                    Jerry / Gyftrot 1180     54,388   <- worst, 4.2x

--   Waterfall        water5/12        530     27,513   <- best
--                    water6          1230     63,852   <- worst, 2.3x

--   Hotland + CORE   CORE rooms       130     15,575   <- best
--                    fire6 / branch   530     63,498
--                    fire5           1380    165,336   <- worst, 10.6x

-- The Hotland/CORE row is the headline: clearing the shared 40-kill pool
-- in the CORE costs about a quarter of what it costs in Hotland's best
-- room, and about a tenth of the worst. The community has recommended
-- the CORE for years; this derives the reason from the game files —
-- both areas reference kill-counter flag 205, and the CORE's encounter
-- object drops to 70/120 steps once the player passes LV 12, which
-- Undyne the Undying's 15,000 EXP award guarantees well in advance.