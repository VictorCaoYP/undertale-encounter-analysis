# Data notes

Explanations for values in the dataset that would otherwise look like errors,
plus mechanics established while extracting the data. Recorded here rather than
in a `notes` column so the tables stay narrow.

---

## Encounter mechanics

**The step formula.** From `scr_steps` in the game's compiled code:

```
population_factor = kills_required / (kills_required - kills_done)
if population_factor > 8: population_factor = 8
steps = (base_steps + round(random(random_steps_max))) * population_factor
```

There is no pity timer. The random roll is re-taken every cycle, so an unlucky
run at the maximum multiplier can take several hundred steps.

**Room transitions reset the counter.** Progress toward the next encounter is lost
on crossing into another room, which is why players accumulate steps by walking
in place rather than pacing between rooms.

**First vs. subsequent encounters.** An encounter object's `Create` event sets the
step target for the first encounter after entering a room; its `Step` event sets
every target after that. The two are usually different — `obj_encounter_ruins1` is
80/40 on entry and 190/80 thereafter — which means re-entering a room may cost
fewer steps than staying in it. The trade-off against walking distance is Q4.

**Kill counters are per-flag, not per-area.** Each encounter object passes a flag
index as its fourth argument: 202 Ruins, 203 Snowdin, 204 Waterfall, 205 Hotland
*and* CORE. Hotland and the CORE therefore share one pool of 40 kills. There is no
206.

**Suppressed encounters in the early Ruins.** Encounters begin spawning in room 3,
but kills are not counted until room 8. That time cannot be recovered by routing.

**No encounters spawn in rooms with a save point.**

---

## Level and EXP

- EXP is overwritten late in the route: defeating Mettaton NEO sets the total to
  50,000 (LV 19) regardless of what was accumulated, and Sans sets LV 20. EXP
  earned earlier is therefore only worth what it buys *within* the areas being
  ground, never banked for later.
- Displayed AT and DF are 10 lower than the internal values used in combat.
- Derived stat formulas: `HP = 16 + 4×LV`, `AT = -2 + 2×LV`, `DF = (LV-1)/4`.
- **LV on arrival in an area is a range, not a fixed number.** The kill count per
  area is fixed but the encounter pool is not, so total EXP depends on which
  monsters appear. A player reaches roughly LV 8 by the end of Snowdin fighting
  whatever shows up, but can reach LV 9 or 10 by favouring high-EXP monsters —
  Gyftrot awards 35, and Ice Cap awards 22 once its hat has been taken. Since
  higher LV means higher AT, and two rooms swap to much cheaper step values at LV
  thresholds, this range is an input to the cost model rather than trivia.
- Two rooms swap in much cheaper step values once the player passes a level
  threshold — Waterfall at LV 10 and the CORE at LV 12. `flag[27]` in the
  Waterfall condition tracks whether required bosses have been defeated and is 0
  throughout this route, so only the LV test matters.

---

## Encounter pools

Most rooms draw from a weighted random pool. Three Snowdin rooms do not:

- `obj_encounterer_jerry` — every encounter includes Jerry, who never appears alone
- `obj_encoutnerer_gyftrot` — every encounter is a Gyftrot

Both carry step parameters of 840/680, roughly four times the 140/280 of the
ordinary Snowdin rooms, so they are poor grinding locations on step cost alone.

Jerry is the clearest candidate for fleeing rather than fighting: he takes 7–10
hits, awards 1 EXP, extends other monsters' attacks, and still consumes a kill.
Fleeing does not advance the kill counter and does not reset step progress, so
which monsters get fought is a genuine choice.

Some monsters never appear alone — Migosp and Ice Cap always arrive alongside
others. Ice Cap awards more EXP and gold after its hat is taken, at a cost of two
extra turns.

---

## Per-row explanations

| Row | Note |
|---|---|
| Froggit (First_Froggit) | 1 internal DEF vs. 4 for ordinary Froggits, though both display 5. Encounterable once. |
| Loox | Awards 7 EXP on the first encounter, then a random 3–24 depending on how often it is ACTed on. Stored as the expected value 13.5. |
| Napstablook | Internal EXP award is −1, a flag meaning the monster cannot be killed. Stored as NULL. Exhausting the Ruins kill counter before entering the room skips the fight entirely, so `fixed_turns` is 0. |
| Monster Kid | Cannot be killed — the attack is intercepted, transitioning to Undyne the Undying. Has wiki stats, but they never apply. |
| Dogamy / Dogaressa | One encounter, two monsters, neither one-shot. Stored as separate rows so turns-to-kill can be computed per target. Internally named `mandog` and `womandog`. |
| Toriel, Papyrus, Muffet, Mettaton NEO | Display ordinary DEF values but carry large negative internal DEF (−9999, −20000, −800, −40000), which guarantees a one-shot. Excluded from any DEF aggregate. |
| Royal Guards | Two guards, both one-shot by the same mechanism, so `fixed_turns` is 2. |
| Mettaton NEO / Sans | Award no EXP; they overwrite the player's total instead. |
| Vegetoid (Overworld) | Two instances in Ruins room 17, triggered by contact rather than by the step counter. Both advance the kill counter. |

---

## Decisions about what to leave out

- **ACT options and spare conditions** were collected and then dropped. This route
  never spares, so they feed no question.
- **Item prices** were dropped for the same reason: every weapon and armor piece on
  this route is found rather than bought, so there is no purchase decision.
- **Gold** was dropped entirely once prices were — it buys nothing that affects
  encounter cost.
- **Rooms without an encounter object** are excluded from `rooms` and counted in
  aggregate on `route_requirements` instead.
