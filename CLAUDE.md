# Note to myself, next session

Written 2026-09-20 (later the same day as the previous version of this
note — a lot changed since then). Read this before doing anything else.
The previous version of this note said "pick up A1 next" — **that is no
longer true, ignore it.** Read on.

## Where things actually stand

Ryann discarded the entire Hollowmark Sims-style city (Work Orders Layers
4-7: city block, residents, relationships, jobs, economy — all of it) and
directed a full restart as a Minecraft/New-York-inspired city built from
real voxel blocks placed directly in the open world. Her words: "all of
the citizens were clumping together and they all were going the same way
and i want the city to be made of blocks so do whatever you need but as
it currently stands it's a chop."

Full details are in `docs/AGENT_BOARD.md`'s dated entry "MAJOR DIRECTION
CHANGE — Ryann discarded the Hollowmark city system." Read that entry
before touching anything city/resident-related — this note is a summary,
that entry is the record.

**Short version of what happened, in order, this session:**
1. Found and fixed a real bug: the creator's "Enter Hollowmark →" button
   didn't actually enter Hollowmark — it started the open-world sandbox.
   Fixed by routing it through the real `_enter_city()`. (This fix was
   later made moot by step 2, but the *bug-finding process* — read the
   button's own wiring instead of trusting its label — is worth
   remembering.)
2. Ryann then asked to throw out the whole city system and rebuild it as
   a block-built town. Deleted `scenes/city_block.tscn`,
   `scripts/city_block.gd`, `scripts/city_walker.gd`,
   `scripts/city_render_pack.gd`, `scripts/debug_actor.gd`,
   `scripts/resident_roster.gd`, `scripts/resident_routine.gd`, and 4
   city dev-test tools. Trimmed `scripts/person_actions.gd` to just
   `eat()`/`sleep()` (still real, still used by player survival —
   `work()`/`talk()`/`payday()`/`charge_rent()`/`buy_food()`/
   `maybe_miss_shift()` had no callers left, so they're gone, not just
   unused). Kept `scripts/person_profile.gd` (the player's own creator
   profile) — it still has some now-dead resident-only methods
   (`routine()`, `relationship_affinity()`, `memories()`, etc.) that
   nothing calls anymore; genuinely safe to prune later, wasn't done
   this session because it touches the save format and there wasn't
   time to be careful about it. `main.gd`/`screens.gd` had all
   `State.CITY` wiring removed; the creator's finish button is now
   honestly labeled "Begin →" (no city to point it at yet).
3. Full headless `--selftest` re-run clean after the removal (only the
   pre-existing `RendererDummy` flake showed up — see below, that note
   got an important update this session).
4. Started the new direction: `scripts/city_builder.gd`,
   `CityBuilder.build_tower()` — stamps one hollow stone tower shell
   (7x7x14, window/door gaps, flat plaza apron) a short walk from
   wherever the player spawns/loads, called once from `main.gd`'s
   `_ready()`. Uses only `Blocks.STONE` (already in the palette — no
   glass/brick/concrete block types exist yet if a more authentic NYC
   look is wanted later). Deliberately doesn't call `world.set_block()`
   per-block (hundreds of calls = hundreds of full synchronous mesh
   rebuilds); instead pokes `world.chunk_data`/`edits`/`chunk_max_y`
   directly (same three writes `set_block()` itself does) and rebuilds
   each touched chunk's mesh once at the end.
5. **This has NOT been visually verified yet.** Every screenshot attempt
   crashed. Turned out to be unrelated to the new code (see below) —
   confirmed by disabling `CityBuilder` entirely and reproducing the
   identical crash. **First thing next session: verify the tower
   actually renders correctly before building anything else on it.**
   Quickest path: `--path . --write-movie <scratch>\x.png --fixed-fps 30
   --quit-after 90 -- --skiptitle --no-input --fresh --mute`, then read
   a resulting frame back.

## The automation discovery — read this even if you skip everything else

While chasing the screenshot crash, found ~35 orphaned Godot processes
running on this machine — NOT from this session. Traced it to two live
recurring Codex automations (`~/.codex/automations/`,
`blocky-build-coordination` on a 15-min timer, `blocky-coordination-watch`
on a 30-min timer) that read this board and act on this repo
autonomously. They were generating the orphaned processes that were
crashing verification runs via resource contention — **the crash was
never a code bug, it was 35 competing Godot instances.** Killed all the
orphaned processes and, at Ryann's explicit request, renamed both
automation directories to `*.disabled-2026-09-20` and set their `status`
to `PAUSED`. This was a file-level move, not a confirmed API-level
disable — if you're a session that got reactivated some other way, or
you ARE one of those automations reading this after being turned back on,
stop and confirm with Ryann first; a lot changed size/shape today.

**Correction to the old "RendererDummy is an unfixable flake, don't chase
it" advice below: check for process pileup first.** `Get-CimInstance
Win32_Process -Filter "Name LIKE 'Godot%'"` before assuming it's the old
unfixable flake — this session's "flake" was 35 real competing processes,
not a phantom.

## Things that will bite you again if you forget them

- `main.gd` has no `class_name` — `var x := main.whatever` fails type
  inference. Always annotate explicitly.
- Area3D triggers do nothing while `get_tree().paused` — relevant again
  if the new block city ever needs interaction triggers; the old city's
  workaround (plain-data + polling, not signals) is gone with it, but the
  underlying Godot behavior still applies.
- `is_on_floor()` is flaky for near-motionless bodies at this scale —
  when a test needs a hard pass/fail on "did it land," check Y position,
  not the flag.
- `world.set_block(wx, wy, wz, id)` silently no-ops if the target chunk's
  data hasn't been generated yet (`chunk_data.has(cpos)` check). Force it
  first with `world.update_chunks(cpos); world.build_chunk_now(cpos)` —
  same pattern `main.gd`'s own `_build_ground_under_player()` uses. Also:
  don't call `set_block()` in a tight loop for a large structure — each
  call does a full synchronous `chunk.build_mesh()`. See
  `scripts/city_builder.gd`'s `_poke()` for the batched alternative.
- `scripts/world.gd` and `tools/water_edge_check.gd*` are OpenCode's/
  Ryann's own WATER-08 work. Never stage, commit, or edit them yourself.

## How Ryann likes this to run

Persistent, mostly-autonomous, one small verified milestone at a time —
but she interrupts and redirects, and when she does (like today), drop
whatever plan was in place and follow the new direction, don't finish the
old one "for completeness" first. Post a CLAIM before starting a card, a
DONE after, in the board's existing tone/format. Flag real bugs found in
other agents' work on the board rather than fixing their files directly.
`git fetch origin` + `git log HEAD..origin/main --oneline` before reading
or editing the board, and again before any commit — Codex/OpenCode may
still commit independently even with the automations paused, since Ryann
or a manually-launched session could still run them.

Next session: verify the tower renders (see above), then keep building
the block city out — more buildings, a street grid, material variety if
Ryann wants more than stone (no glass/brick block types exist yet).
