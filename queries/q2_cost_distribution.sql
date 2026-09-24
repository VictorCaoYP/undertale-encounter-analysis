-- Q2 — How back-loaded is each area?

-- Splits each room's kills into four equal groups by order, then asks
-- what share of that area's total walking falls in the last group.

-- Reads the 'kill_costs' view from Q1.
-- Note on the shape of the answer: each room's cost is a constant
-- ('step_constant') multiplied by the population factor. Because this
-- query reports a RATIO, that constant appears in both the numerator and
-- the denominator and cancels out — so the percentage is identical for
-- every room in an area, and identical whether a room runs at its base
-- or its alt step values. The figure describes the game's encounter
-- formula rather than any particular room.


-- Monsters tend to appear less often in Ruins and Snowdin as the kill counter goes up
-- Therefore we split the total kill counts into 4 quartiles and determine how many steps the final few kills take
WITH quartiles AS (
    SELECT *, NTILE(4) OVER (PARTITION BY area, room_id ORDER BY kills_done) AS quartile
    FROM kill_costs
)

-- Shows how much percentage does the final few kills take
-- Ruins require 20 kills, so we find how much percentage of steps do the final 5 kills 
SELECT
    area,
    argument3                                                   AS counter_flag,
    COUNT(DISTINCT kills_done)                                  AS kills_total,
    COUNT(DISTINCT CASE WHEN quartile = 4 THEN kills_done END)  AS kills_in_last_quarter,
    ROUND(100.0 * SUM(CASE WHEN quartile = 4 THEN expected_steps ELSE 0 END)
          / SUM(expected_steps), 1)                             AS pct_in_last_quarter
FROM quartiles
GROUP BY area
ORDER BY pct_in_last_quarter DESC;


