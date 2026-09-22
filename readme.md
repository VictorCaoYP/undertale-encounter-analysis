# Undertale Encounter Cost Analysis

A SQL analysis of how long it takes to clear every random encounter in *Undertale*'s
No Mercy route, built on data extracted directly from the game's compiled files.

**Status:** in progress. Data collection and the cost model are complete; the
remaining analysis queries are being written. See [Progress](#progress) below.

---

## The question

The No Mercy route requires the player to defeat a fixed number of random
encounters in each area before the story advances. Encounters are triggered by a
step counter, and the number of steps required grows as the area empties — so the
last few kills in an area take dramatically longer than the first few.

**How should a player minimize the time spent grinding those encounters?**

Boss fights are included in the dataset as fixed costs, so the analysis can also
answer a second question: *how much of the route is optimizable at all?*

---

## Why this needed real data

The encounter rate is not a constant. The game picks a target step count from this
formula every time an encounter resets:

```
steps = (base_steps + random(0..random_steps_max)) × population_factor

population_factor = kills_required / (kills_required − kills_done)   [capped at 8]
```

Two things follow from that, and neither is obvious from playing:

1. **The cost curve is hyperbolic, not linear.** In a 20-kill area, the first kill
   costs 1× the base rate and the last costs 8×. Most of an area's walking happens
   in its final quarter.
2. **`base_steps` and `random_steps_max` vary by room.** Rooms in the same area can
   differ by more than a factor of two, so *where* you grind is a real decision.

Community guides describe both effects qualitatively. This project quantifies them.

---

## Data

### Sources

| Table | Source |
|---|---|
| `rooms` | Extracted from the game's compiled data with UndertaleModTool — the `Create` and `Step` events of each `obj_encounter_*` object |
| `route_requirements` | Kill thresholds read from the same encounter scripts (`argument2`) and cross-checked against the wiki's flag table |
| `monsters` | Undertale Wiki, using internal stat values rather than in-game displayed values |
| `items`, `exp_to_lv` | Undertale Wiki |
| `free_kills` | Verified in-game |

Room step parameters are not published on the wiki. They were read out of the game
files, which is why the `rooms` table carries the `encounter_object` name verbatim —
typos and all (`obj_encounterer_ruins3`, `obj_encoutnerer_gyftrot`) — so any figure
here can be traced back to a specific object in the source.

### Schema

Six tables. `schema.sql` has the full DDL.

```
route_requirements  one row per area — kill thresholds, room counts, counter flag
rooms               one row per grindable room — step parameters per encounter object
monsters            one row per stat block — not per monster name
items               weapons and armor (no prices: all are found, not bought)
exp_to_lv           LV thresholds and the stats granted at each level
free_kills          encounters that yield kills with no walking cost
```

### Modeling decisions worth knowing about

**`monsters` is keyed on stat block, not name.** Some monsters have more than one
stat block — the first Froggit encountered has 1 DEF while ordinary Froggits have 4,
though both display 5 when checked. Those are two rows, separated by a `variant`
column, because collapsing them would make any "cost to kill a Froggit" figure wrong.

**Displayed stats and internal stats are stored separately.** The `*_check` columns
hold what the game shows the player; `*_actual` holds what the combat math uses. The
gap is the mechanism behind guaranteed one-shots — several bosses display an ordinary
DEF value while internally carrying −9999 or −20000.

**`NULL` and `0` mean different things in `fixed_turns`.** A number means the fight
lasts a scripted number of turns regardless of the player's stats. `0` means the
encounter can be skipped entirely with correct routing. `NULL` means the duration is
computed from stats and player attack.

**Sentinel values are not stored in numeric columns.** Napstablook's EXP award is
internally −1, a flag meaning "cannot be killed" rather than a quantity; that column
holds `NULL` and the −1 is recorded in the notes. Storing it as written would quietly
corrupt every `SUM` and `AVG` over the column.

**Hotland and the CORE share a kill counter.** Both areas' encounter objects reference
flag index 205, which is verifiable in the source rather than taken on faith. The 40
required kills are recorded once, on Hotland, so route totals don't double-count.

---

## Progress

| | |
|---|---|
| Data collection (6 tables, ~120 rows) | done |
| Schema and typed import into SQLite | done |
| **Q1** — cost per kill and cumulative cost curve | done (`queries/q1_kill_costs.sql`) |
| **Q2** — share of walking that falls in the final quarter of an area | in progress |
| **Q3** — which room in each area is cheapest to grind | pending |
| **Q4** — whether re-entering a room beats walking in place | pending |
| **Q5** — when fleeing an encounter beats fighting it | pending |
| Visualization of the cost curve | pending |

---

## Repository layout

```
schema.sql            table definitions
queries/              analysis queries, one file per question
data/                 source data as CSV
notes/data_notes.md   per-row explanations for unusual values
undertale.db          SQLite database (importable from data/ via schema.sql)
```

To reproduce: create an empty SQLite database, run `schema.sql`, then import each
CSV in `data/` into the matching table. Import `route_requirements` first.

---

## Limitations

- **Expected values, not simulations.** The model uses the mean of the random step
  roll. Any individual playthrough varies with RNG; there is no pity timer.
- **Steps and turns, not seconds.** Movement speed, room geometry, menu inputs and
  cutscenes are not modeled, so this measures encounter cost rather than wall-clock
  time.
- **Attack timing is not modeled.** Hitting the center of the attack bar increases
  damage and can reduce a fight by a turn. That multiplier is not in the dataset.
- **Room re-entry cost is not modeled.** Crossing a room transition resets the step
  counter, but walking to the transition has a cost this data can't measure.
- **Rooms 3–8 of the Ruins** spawn encounters whose kills are suppressed. That time
  is unrecoverable by any routing decision and is excluded from the model.

---

## A note on terminology

The route analyzed here is the one in which the player defeats every enemy in each
area. The player community's name for it carries meaning outside gaming that doesn't
belong on a technical write-up, so this repository refers to it as the **No Mercy
route** — also an in-game term — or as a combat completion route.
