# Tier 0 = the first 3 monster fights of the act (STS2 rule), not rows 0-2

Status: PLAN, nothing implemented. Written 2026-09-16 for a separate session to execute.
Verdicts already given by Julien: hybrid variant (only tier 0 moves to a fight count, tiers 1
and 2 keep the row-8 cut), secret fights from event rooms count toward the 3, the tutorial
fight counts as fight #1, elites and the boss never count.

## 1. What changes for the player

Today `run.gd::_get_tier_for_room` serves tier 0 to any monster room on rows 0-2, tier 1 on
rows 3-7, tier 2 on rows 8+. Row 0 is always a fight (`map_generator.gd:167`), so fight #1 is
the same under both systems. Elites and campfires can't appear before row 5, so rows 1-4 are
only fight / shop / event. A player who takes a shop and an event on rows 1-2 gets their
second fight on row 3, drawn from tier 1. A player who fights three times in a row gets three
tier-0 fights. The current rule punishes the event-heavy opening.

After this change every path gets exactly 3 tier-0 fights (fewer only if the whole path has
fewer than 3 monster fights, which the map can produce but rarely does). Fights #4 onward use
the row rule exactly as today. No path gets harder, event-heavy openings get easier on rows
3-5.

Reference behaviour, verified in the STS2 decompile (`Desktop\sts2_ref\pck\src\Core`):
`Models/ActModel.cs:347-370` builds a queue of 15 normal encounters at act start, the first
`NumberOfWeakEncounters` (3) from the `IsWeak` pool, the rest from the regular pool.
`Rooms/RoomSet.cs:72` serves `normalEncounters[normalEncountersVisited % Count]`, and
`Runs/RunManager.cs:1231` bumps that counter when a room is ENTERED. Elites have their own
queue and counter. Floor never enters the calculation. STS2 has no third tier, its regular
pool is flat for the rest of the act, so there is no reference to copy for our T1/T2 split.
That split stays on rows.

## 2. Design

- New run-scoped state: `monster_fights_this_act: int`. Lives on `Run` (run.gd) next to
  `used_battles`, not on Global. Nothing outside run.gd reads it.
- Counts every entry through `_on_battle_room_entered` whose room is NOT elite and NOT boss.
  That covers `Room.Type.MONSTER` and `Room.Type.EVENT` with `is_secret_fight` (both reach
  `_on_battle_room_entered`, see `run.gd:748-753` and `run.gd:763-768`). The tutorial fight is
  served through the same function on row 0, so it counts as fight #1 with no special case.
- The debug fight picker (`run.gd::_debug_start_fight`, line 1025) bypasses
  `_on_battle_room_entered` and must NOT count. No change needed there.
- Tier rule, as a pure static function so a harness can pin it without instantiating Run:

```gdscript
# Tier 0 is the first TIER0_FIGHT_COUNT monster fights of the act, whatever row they fall
# on (STS2's "3 weak encounters" rule, 2026-09-16). Tiers 1 and 2 stay on the row-8 cut the
# balance passes were tuned on. Elites and the boss ignore both. Secret fights from event
# rooms reach this with room_type == EVENT and count like monsters, same as STS unknown rooms.
const TIER0_FIGHT_COUNT := 3

static func tier_for(room_type: Room.Type, row: int, monster_fights_so_far: int) -> int:
    if room_type == Room.Type.BOSS:
        return 4
    if room_type == Room.Type.ELITE:
        return 3
    if monster_fights_so_far < TIER0_FIGHT_COUNT:
        return 0
    return 2 if row > 7 else 1
```

  `_get_tier_for_room(room)` becomes a one-liner:
  `return tier_for(room.type, room.row, monster_fights_this_act)`.
  Rows 0-2 with a count of 3 or more are unreachable (at most one fight can precede row 1),
  the function returns 1 there. Harmless.
- Increment AFTER the tier is computed, in `_on_battle_room_entered`, gated on `tier < 3`:

```gdscript
    var tier = _get_tier_for_room(room)
    if tier < 3:
        monster_fights_this_act += 1
```

  Fight #1 is served with the count at 0, fight #4 with the count at 3.
- Reset: `_enter_act_2()` (run.gd:718) sets it to 0 next to `used_battles.clear()`.
  `_start_run()` (run.gd:~300) also sets it to 0 explicitly, even though a fresh Run instance
  starts at 0, so the reset is visible next to `Global.current_act = 1`.
- Save: key `"monster_fights_this_act"` in the `SaveManager.write_save` dict (run.gd:1421),
  next to `"used_battles"` (line 1449). Checkpoints are only written in `_show_map()`, after a
  room resolves, so quitting mid-fight resumes with the pre-fight count. That matches the
  existing "quit mid-fight = resume at the last map checkpoint" behaviour.
- Load (run.gd:1462 `_load_run`): restore with a fallback for saves written before this key.
  The map save already carries `selected` and `secret` per room, and a checkpoint is only
  ever taken with every selected fight room already resolved, so the count can be rebuilt:

```gdscript
    # Must run AFTER map.load_from_save_data (run.gd:1561): the fallback walks map_data.
    if data.has("monster_fights_this_act"):
        monster_fights_this_act = data["monster_fights_this_act"]
    else:
        monster_fights_this_act = _count_walked_monster_fights()

func _count_walked_monster_fights() -> int:
    var count := 0
    for floor_rooms: Array in map.map_data:
        for room: Room in floor_rooms:
            if not room.selected:
                continue
            if room.type == Room.Type.MONSTER \
                    or (room.type == Room.Type.EVENT and room.is_secret_fight):
                count += 1
    return count
```

  Place the restore after line 1561, not next to the `used_battles` restore at 1547, or the
  fallback reads an empty map.

## 3. Files and exact edits

| File | Edit |
|---|---|
| `scenes/run/run.gd` | `var monster_fights_this_act := 0` next to `used_battles`. `const TIER0_FIGHT_COUNT := 3`. New `static func tier_for(...)`. `_get_tier_for_room` delegates to it. Increment in `_on_battle_room_entered` right after `var tier = _get_tier_for_room(room)` (line 449). Reset in `_start_run` and `_enter_act_2`. Save key at 1449. Restore + `_count_walked_monster_fights()` after 1561. |
| `scenes/run/run.gd` comments | Line 21-22: "12 entries, 9 of them collapse into slimes, 3 distinct picks for the 3 tier-0 floors" is stale twice over. Tier 0 is 9 entries today, 6 in the `slimes` group (Venom Bloom, Marauder, Skeleton solo are the other 3), and "floors" becomes "fights". Line 586-587: "past 3 tier-0 fights, which act 1 can't reach" becomes "tier 0 is served exactly 3 times per act by construction, so the reset can only trigger if the pool shrinks below 3 distinct groups". |
| `debug_map_paths.gd` (root, NOT committed) | `_tier_for(room)` takes the monster count so far. The DP key already carries `t0`, `t1`, `t2`, so the count is `t0 + t1 + t2` of the state being extended. Call `Run.tier_for(nxt.type, nxt.row, t0 + t1 + t2)` instead of the row copy. Note: `Run` is a `class_name`, check `scenes/run/run.gd` still declares it before relying on it from the harness, and never `load()` run.gd by path before run.tscn in the same process (memory: class_name script before its scene). |
| `act1_act2_encounter_plan_2026-09.md` | One line in the change log table: tier 0 is now the first 3 monster fights of the act, rows no longer matter for T0, T1/T2 unchanged. The 20k-path variety sim behind the Gap Check assumed rows for T0. Its conclusions hold in count (still at most 3 T0 fights) but the floor spread of those fights changes. |
| `CLAUDE.md` | TL;DR bullet per project convention. Also correct the "au 1er run les floors 1-3 sont un set DÉTERMINISTE" sentence in the T0 rework bullet: it is now "the first 3 fights", which can land on rows 0-5. |

Not touched, on purpose:
- `map_generator.gd::_finalize_room` (line 284) pre-picks a fight by row at generation. run.gd
  overrides it at room entry and its own comment says so. Leave it.
- `map_generator.gd::_finalize_room` event tier by row (line 300). run.gd always draws events
  at tier 0 (`run.gd:772`). Leave it.
- `ACT2_SOURCE_TIER`, `battle_scene.act_tier`, the `used_battles` tier reset and the group burn
  all key off the tier VALUE, so act 2 gets "first 3 fights draw from the act-1 tier-1 pool"
  for free.
- `Global.reset_run_state()`: the counter is a Run member, reinitialised with the scene.

## 4. Harness (root, `debug_tier_count.gd` + `.tscn`, name it `debug_*` for the export filter)

Boot a real scene (never `--script`, the autoloads are needed for `Room` to load). Sections:

- **A, pure function table.** `Run.tier_for(type, row, count)`:
  - MONSTER row 0 count 0 → 0. MONSTER row 5 count 2 → 0 (the new behaviour, a third fight on
    row 5 is still tier 0). MONSTER row 5 count 3 → 1. MONSTER row 8 count 3 → 2.
    MONSTER row 8 count 1 → 0 (a second fight taken late is still a warmup, same as STS2).
  - EVENT row 3 count 1 → 0 (secret fight counts as monster).
  - ELITE row 6 count 0 → 3. BOSS row 14 count 0 → 4 (count never touches elites/boss).
- **B, the counter through the real entry path.** Instantiate `run.tscn`, drive
  `_on_battle_room_entered` three times with MONSTER rooms and once with an ELITE room, assert
  `monster_fights_this_act == 3`, then a fourth MONSTER on row 4 → `_get_tier_for_room` gives 1.
  ⚠️ `run.tscn` and `main_menu.tscn` hang inside a SubViewport (documented). Add it to the tree
  directly, and if `_late_init` boots a full run on `_ready`, prefer testing `_get_tier_for_room`
  + the increment on a bare `Run.new()` with `monster_fights_this_act` set by hand. Section A
  already pins the rule, B only has to prove the increment and the `tier < 3` gate.
- **C, save round trip.** Build the save dict, assert the key is present, then delete the key
  from the dict and run `_count_walked_monster_fights()` on a map with two selected MONSTER
  rooms, one selected secret-fight EVENT, one selected ELITE, one unselected MONSTER → 3.
- **D, negative control.** Remove the `tier < 3` gate and A/B must fail (an ELITE bumps the
  count and the fourth MONSTER comes out tier 1 one fight early). Put the gate back.
- Re-run `debug_map_paths.gd` before and after and paste both distributions in the CLAUDE.md
  bullet: how many paths had fewer than 3 tier-0 fights under rows, and the new T0/T1/T2 counts
  per path. That is the number Julien will want.

Verify with `gdtoolkit` on run.gd and the harness, then `--headless --import` once before the
harness (fresh worktree trap). Regressions to re-run: `debug_double_endturn` (boots the real
battle path), any `debug_map_*` harness present at the root.

## 5. Things that look like bugs after the change and are not

- A fight on row 5 that is easier than the elite two rows earlier. Intended, a player who
  saved warmups gets them late.
- The first-run "deterministic floors 1-3" observation in CLAUDE.md. Still deterministic in
  content (the tutorial burns the Skeleton solo, leaving exactly 3 distinct T0 picks on run
  #1), no longer pinned to floors 1-3.
- An old save resuming at floor 6 with three fights already taken shows tier-1 fights, not
  tier-0. That is the fallback in §2 working, not a missing reset.

## 6. Open, not blocking

- Should `TIER0_FIGHT_COUNT` differ in act 2? STS2 uses 3 in every act. Leave at 3.
- `debug_map_paths.gd` is uncommitted. Committing it with the count-aware DP would give the
  encounter plan a reproducible number. Julien's call.
