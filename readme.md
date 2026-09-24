# Undertale Encounter Cost Analysis

A SQL analysis of how long it takes to clear every random encounter in *Undertale*'s
No Mercy route, built on data extracted directly from the game's compiled files.

**Status:** in progress. Data collection and the cost model are complete; the
remaining analysis queries are being written. See [Progress](#progress) below.

\---

## The question

The No Mercy route requires the player to defeat a fixed number of random
encounters in each area before the story advances. Encounters are triggered by a
step counter, and the number of steps required grows as the area empties — so the
last few kills in an area take dramatically longer than the first few.

**How should a player minimize the time spent grinding those encounters?**

Boss fights are included in the dataset as fixed costs, so the analysis can also
answer a second question: *how much of the route is optimizable at all?*

\---

## Why this needed real data

The encounter rate is not a constant. The game picks a target step count from this
formula every time an encounter resets:

'''
steps = (base\_steps + random(0..random\_steps\_max)) × population\_factor

population\_factor = kills\_required / (kills\_required − kills\_done)   \[capped at 8]
'''

Two things follow from that, and neither is obvious from playing:

1. **The cost curve is hyperbolic, not linear.** In a 20-kill area, the first kill
costs 1× the base rate and the last costs 8×. Most of an area's walking happens
in its final quarter.
2. **'base\_steps' and 'random\_steps\_max' vary by room.** Rooms in the same area can
differ by more than a factor of two, so *where* you grind is a real decision.

Community guides describe both effects qualitatively. This project quantifies them.

\---

## Findings

### How back-loaded is each area?

|Area|Kills required|Kills in final quarter|Share of total walking|
|-|-|-|-|
|Snowdin|16|4|55.0%|
|Hotland|40|10|54.9%|
|Core|40|10|54.9%|
|Ruins|20|5|54.6%|
|Waterfall|18|4|51.0%\*|

(Hotland and the Core return the same figure because they are one kill
counter seen from two areas.)

**The final quarter of an area's required kills accounts for roughly 55% of all the
walking — more than the other three quarters combined.** A kill in that final
quarter costs about **3.6×** what an average earlier kill costs.

The consistency across areas is not a coincidence. Because the population factor
divides 'kills\_required' by itself, the shape of the cost curve is the same no
matter how many kills an area demands. This is a property of the game's encounter
formula, not of any particular area.

The practical consequence drives the rest of the analysis: **anything that removes
a kill from the end of an area is worth roughly 3.6 kills removed from the
beginning.** Free kills, fled encounters and routing choices are all evaluated
against that.

\* Waterfall reads lower only because 18 kills do not divide evenly into quartiles —
'NTILE(4)' gives it groups of 5, 5, 4, 4, so its final group holds 4 of 18 kills
rather than a true quarter. It is not a real difference. Waterfall also crosses the
LV 10 step-value threshold partway through the area in most playthroughs, which
would push its true figure somewhat lower still.

### Which room should you grind in?

Total steps to clear a counter's full kill requirement without leaving the room:

|Counter|Best room||Worst room||Spread|
|-|-|-|-|-|-|
|Ruins (20 kills)|'ruins15B/C/D'|9,852|'ruins10'|21,153|2.1×|
|Snowdin (16)|'tundra3/4/6'|12,906|Jerry / Gyftrot rooms|54,388|4.2×|
|Waterfall (18)|'water5/12'|27,513|'water6'|63,852|2.3×|
|**Hotland + CORE (40)**|**CORE rooms**|**15,575**|'fire5'|165,336|**10.6×**|

**Clearing Hotland and the CORE's shared 40-kill pool costs about 15,600 steps in a
CORE room against 63,500 in Hotland's best — and 165,000 in 'fire5', the most
expensive grinding location in the game.** A player who picks the wrong Hotland room
walks more than ten times as far as one who moves to the CORE.

Players have recommended the CORE for years as a rule of thumb. This derives the
reason from the game files: both areas reference kill-counter flag 205, so kills in
either draw from the same pool, and the CORE's encounter object drops from 240/50
steps to 70/120 once the player passes LV 12 — a threshold that Undyne the Undying's
15,000 EXP award clears well in advance, putting the player at roughly LV 17 before
Hotland begins.

Note that the two effects compound. Because the final quarter of kills carries \~55%
of the walking, moving to the CORE is worth most precisely where the grind is
already worst.

\---

## Data

### Sources

|Table|Source|
|-|-|
|'rooms'|Extracted from the game's compiled data with UndertaleModTool — the 'Create' and 'Step' events of each 'obj\_encounter\_\*' object|
|'route\_requirements'|Kill thresholds read from the same encounter scripts ('argument2') and cross-checked against the wiki's flag table|
|'monsters'|Undertale Wiki, using internal stat values rather than in-game displayed values|
|'items', 'exp\_to\_lv'|Undertale Wiki|
|'free\_kills'|Verified in-game|

Room step parameters are not published on the wiki. They were read out of the game
files, which is why the 'rooms' table carries the 'encounter\_object' name verbatim —
typos and all ('obj\_encounterer\_ruins3', 'obj\_encoutnerer\_gyftrot') — so any figure
here can be traced back to a specific object in the source.

### Schema

Six tables. 'schema.sql' has the full DDL.

'''
route\_requirements  one row per area — kill thresholds, room counts, counter flag
rooms               one row per grindable room — step parameters per encounter object
monsters            one row per stat block — not per monster name
items               weapons and armor (no prices: all are found, not bought)
exp\_to\_lv           LV thresholds and the stats granted at each level
free\_kills          encounters that yield kills with no walking cost
'''

### Modeling decisions worth knowing about

**'monsters' is keyed on stat block, not name.** Some monsters have more than one
stat block — the first Froggit encountered has 1 DEF while ordinary Froggits have 4,
though both display 5 when checked. Those are two rows, separated by a 'variant'
column, because collapsing them would make any "cost to kill a Froggit" figure wrong.

**Displayed stats and internal stats are stored separately.** The '\*\_check' columns
hold what the game shows the player; '\*\_actual' holds what the combat math uses. The
gap is the mechanism behind guaranteed one-shots — several bosses display an ordinary
DEF value while internally carrying −9999 or −20000.

**'NULL' and '0' mean different things in 'fixed\_turns'.** A number means the fight
lasts a scripted number of turns regardless of the player's stats. '0' means the
encounter can be skipped entirely with correct routing. 'NULL' means the duration is
computed from stats and player attack.

**Sentinel values are not stored in numeric columns.** Napstablook's EXP award is
internally −1, a flag meaning "cannot be killed" rather than a quantity; that column
holds 'NULL' and the −1 is recorded in the notes. Storing it as written would quietly
corrupt every 'SUM' and 'AVG' over the column.

**Hotland and the CORE share a kill counter.** Both areas' encounter objects reference
flag index 205, which is verifiable in the source rather than taken on faith. The 40
required kills are recorded once, on Hotland, so route totals don't double-count.

\---

## Progress

|||
|-|-|
|Data collection (6 tables, \~120 rows)|done|
|Schema and typed import into SQLite|done|
|**Q1** — cost per kill and cumulative cost curve|done ('queries/q1\_kill\_costs.sql')|
|**Q2** — share of walking that falls in the final quarter of an area|done ('queries/q2\_cost\_distribution.sql')|
|**Q3** — which room in each area is cheapest to grind|done ('queries/q3\_best\_grind\_room.sql')|
|**Q4** — whether re-entering a room beats walking in place|pending|
|**Q5** — when fleeing an encounter beats fighting it|pending|
|Visualization of the cost curve|pending|

\---

## Repository layout

'''
schema.sql            table definitions
queries/              analysis queries, one file per question
data/                 source data as CSV
notes/data\_notes.md   per-row explanations for unusual values
undertale.db          SQLite database (importable from data/ via schema.sql)
'''

To reproduce:

1. Create an empty SQLite database and run the 'CREATE TABLE' section of 'schema.sql'.
2. Import each CSV in 'data/' into its matching table, 'route\_requirements' first.
3. Run the two 'UPDATE' statements in the post-import section at the bottom of
'schema.sql'. These set 'alt\_applies', which decides whether a room runs at its
base or its LV-gated step values.
4. Run 'queries/q1\_kill\_costs.sql' to build the 'kill\_costs' view.
5. Run 'queries/q2\_\*.sql' and 'queries/q3\_\*.sql', which read from it.

Each query file ends with the result it produced, so the findings above can be
checked against the queries without running anything.

\---

## Limitations

* **Expected values, not simulations.** The model uses the mean of the random step
roll. Any individual playthrough varies with RNG; there is no pity timer.
* **Steps and turns, not seconds.** Movement speed, room geometry, menu inputs and
cutscenes are not modeled, so this measures encounter cost rather than wall-clock
time.
* **Attack timing is not modeled.** Hitting the center of the attack bar increases
damage and can reduce a fight by a turn. That multiplier is not in the dataset.
* **Room re-entry cost is not modeled.** Crossing a room transition resets the step
counter, but walking to the transition has a cost this data can't measure.
* **Rooms 3–8 of the Ruins** spawn encounters whose kills are suppressed. That time
is unrecoverable by any routing decision and is excluded from the model.

\---

## A note on terminology

The route analyzed here is the one in which the player defeats every enemy in each
area. The player community's name for it carries meaning outside gaming that doesn't
belong on a technical write-up, so this repository refers to it as the **No Mercy
route** — also an in-game term — or as a combat completion route.

## Sources
https://undertale.fandom.com/wiki/Main_Page
https://undertale.fandom.com/wiki/Category:Enemies
https://undertale.fandom.com/wiki/Genocide_Route
https://underminersteam.github.io/
