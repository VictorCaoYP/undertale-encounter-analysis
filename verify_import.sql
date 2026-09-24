-- verify_import.sql

-- 1. Row counts. Expect 6, 44, 30, 15, 20, 2.

SELECT 'route_requirements' AS t, COUNT(*) AS n FROM route_requirements
UNION ALL SELECT 'monsters',   COUNT(*) FROM monsters
UNION ALL SELECT 'rooms',      COUNT(*) FROM rooms
UNION ALL SELECT 'items',      COUNT(*) FROM items
UNION ALL SELECT 'exp_to_lv',  COUNT(*) FROM exp_to_lv
UNION ALL SELECT 'free_kills', COUNT(*) FROM free_kills;


-- 2. Column types. Both should return 'integer'.

-- 'text' means an import wizard created its own table instead of using
-- the DDL in schema.sql, in which case base_steps * pop_factor performs
-- string concatenation rather than arithmetic and every cost figure is
-- silently wrong.

SELECT typeof(base_steps) AS base_steps_type,
       typeof(random_steps_max) AS random_steps_type
FROM rooms LIMIT 1;


-- 3. alt_applies. Expect exactly 7 rows: the five Core rooms, plus
--    water6 and fire5.
--
-- If this returns nothing, the post-import UPDATE statements at the
-- bottom of schema.sql were not run, and the CORE will be charged its
-- base rate (530 steps per encounter) instead of its LV-gated rate
-- (130) — a fourfold error in the project's headline finding.

SELECT area, internal_room_name, alt_applies
FROM rooms WHERE alt_applies = 1
ORDER BY area, room_id;


-- 4. encounter_type vocabulary. Expect only 'farmable', 'fixed' and
--    'one-time'. Anything else is a typo that will silently drop rows
--    from any query filtering on this column.

SELECT encounter_type, COUNT(*) AS n
FROM monsters GROUP BY encounter_type ORDER BY n DESC;


-- 5. Mandatory kills. Every monster below sets a murder-level flag in
--    the game's own progression table, so each must be 'fixed'.
--    Moldbygg is deliberately NOT in this list — it is farmable.

SELECT name, area, encounter_type
FROM monsters
WHERE name IN ('Toriel','Doggo','Lesser_Dog','Dogamy','Dogaressa',
               'Greater_Dog','Snowdrake','Papyrus','Shyren','Glad_Dummy',
               'Undyne_the_Undying','Royal_Guards','Muffet','Mettaton_NEO')
  AND encounter_type <> 'fixed';
-- Zero rows returned = correct.



-- 6. The view. Expect 724 rows, five areas including Core, and a
--    step_constant of 130 for the Core.

SELECT COUNT(*) AS kill_costs_rows FROM kill_costs;

SELECT DISTINCT area FROM kill_costs ORDER BY area;

SELECT DISTINCT step_constant FROM kill_costs WHERE area = 'Core';
