# Roadmap

Rule for this project: one small milestone at a time, each one runnable
and verified before the next starts. No system gets built "all at once."

## Done

- [x] **M0 — It runs.** Godot 4 project opens and shows a lit, flat-shaded
      3D scene.
- [x] **M1 — Chunks.** World stored as 16x64x16 chunks of block IDs, each
      meshed as one mesh with only the visible faces (`chunk.gd`).
- [x] **M2 — Player.** Small blocky character, walk / run / jump, gravity,
      collision, right-shoulder third-person camera (`player.gd`).
- [x] **M3 — Terrain.** Noise heightmap with beaches, hills, snow caps,
      trees, and a water plane. Chunks stream in around the player
      (`world_gen.gd`, `world.gd`).
- [x] **M4 — Break / place.** Aim with the crosshair, LMB breaks, RMB
      places the hotbar block (keys 1-7).
- [x] **M5 — Day/night.** Sun and moon orbit once per 10-minute day; sky,
      fog, sunlight and ambient blend through day / sunset / night
      palettes. Clock on the HUD, hold T to fast-forward (`day_night.gd`).

- [x] **M6 — Biomes.** Temperature + moisture noise pick Plains / Forest /
      Desert / Tundra per column (ground blocks, tree density) and tint
      grass and leaves smoothly across the map. HUD shows the biome.
      Trees are decided per world column so they cross chunk edges.

- [x] **M7 — First creature.** A boxy four-legged critter that idles and
      wanders, hops 1-block steps, avoids cliffs and water. Spawns in
      small groups per chunk with a biome-colored coat; despawns when far
      (`creature.gd`, spawner in `world.gd`).

- [x] **M8 — Inventory.** Breaking a block puts it in your inventory;
      placing spends one. Hotbar shows counts (`inventory.gd`).

- [x] **M9 — Combat.** Left click punches a creature under the crosshair
      within 3 blocks (else breaks a block). Creatures have 3 health,
      flash red, get knocked back and flee; at 0 they die and leave a
      Meat drop you walk over to collect (`drop.gd`).

- [x] **M10 — Player health.** 10 health, fall damage past 3 blocks, red
      hurt flash, "You died" + respawn at spawn with full health, E eats
      Meat to heal 4. Chunky health bar above the hotbar.

- [x] **M11 — Progression.** Kills give 5 XP; level N needs 10×N XP.
      Each level adds +2 max health and fully heals. Gold XP bar with
      "Lv N", "Level N!" banner.

- [x] **M13 — Performance.** Measured first (meshing was 18.8 ms/chunk
      on the main thread; worst frame 75 ms at radius 8). Mesher rewritten
      (5.4 ms), then generation + meshing moved to worker threads, and
      collision shapes limited to chunks near the player. Result: worst
      frame 12 ms, view radius 4 → 8 (64 → 128 blocks). `--perf` prints
      the numbers.
- [x] **M12 — Saving.** One JSON save (`user://save.json`): seed + block
      edits (terrain regenerates, only the diff is stored), player
      position/look/health/level/XP/inventory, time of day. Autosave
      every 30 s, on window close, and F5. Loads on start; `--fresh` skips.

- [x] **M14 — Tools & crafting.** Tab opens inventory + recipe list.
      Log → planks → sticks → workbench; wooden/stone pickaxe and axe at
      a workbench. Owning the best tool speeds up its block class; stone
      only drops with a pickaxe. No durability yet.

- [x] **M15 — The Shade.** A tall dark night creature with glowing eyes
      spawns out of sight after dark (max 6), hunts you within 18 blocks
      at walking pace, bites for 2 with knockback, ignores pain, and
      burns away in daylight. "Night falls" / "Dawn" banners.

- [x] **M16 — Sound.** Everything synthesized in code at startup
      (`sfx.gd`): footsteps by surface, dig/place/hit/hurt/bite/groan,
      pickup, eat, die, day birds / night wind ambience.

- [x] **M17 — Caves & ores.** 3D-noise tunnels (mouths only in "cave
      country"), coal ore anywhere in stone, iron ore below y 22. Ores
      drop Coal / Iron; tool tiers (iron ore needs a stone pickaxe);
      iron pickaxe/axe recipes.

- [x] **M18 — Screens.** Title (Continue / New Game with seed / Quit),
      pause (Esc: Resume / Save / sound slider / Quit to Title), death
      (Respawn / Quit to Title), and a Minecraft-style inventory grid with
      icon-based recipes. One state machine in `main.gd` owns screens,
      pausing and the mouse. Tests use their own save file.

- [x] **M19 — Minecraft-style inventory.** 36 slots with stacks, the
      hotbar is the first row, tools must be held. 2×2 / 3×3 crafting
      grids with shaped and shapeless recipes, a result slot, drag/drop,
      split and shift-craft. Right-click a Workbench to open the 3×3.
- [x] **M20 — Real textures and a real player model.** Vendored a
      generated asset pack at `res://blocky/` (16×16 block/item
      textures, 21 GLB models, palette). Chunks now emit UVs from
      `BlockAtlas` instead of flat vertex color (biome tint on grass
      top/leaves survives as a multiply tint over neutral texture); the
      water plane got a tiled texture. The player is now `player.glb`
      (21 named parts) rigged at runtime in `player.gd::_build_model()` —
      pivots computed from live mesh AABBs, not hand-copied numbers —
      scaled to our 1.3-tall body, with a short sword attached to the
      right hand (cosmetic only, no swing/combat yet). See `PLAN.md`
      for the full multi-phase asset-integration plan this milestone
      started, and `ART.md` for the asset-by-asset checklist.
- [x] **M21 — Item icons.** `Blocks.icon(id)` reuses each block's own
      world texture (or the item's own icon file) for the hotbar,
      inventory grid, cursor stack and dropped-item cubes — no new
      art, full coverage. `Blocks.COLORS`/`face_color()` (now fully
      unused) removed rather than left as dead code.
- [x] **M22 — Named mobs.** Every mob GLB now spawns as its own kind
      instead of the tinted-box placeholder: wildlife (rabbit, deer,
      fox, boar, bird — `Creature` subclasses, random pick per spawn
      in `world.WILDLIFE_SCENES`) and night hunters (goblin, wisp,
      witch, alongside the original box Shade — `Hostile` subclasses,
      random pick in `world.HOSTILE_SCENES`). All behavior/stats are
      still whatever the base class already had (wander/flee/die for
      wildlife; chase/bite/burn-at-dawn for hostiles) — only the look
      changed. The shared rig-instantiate/rescale/red-flash-overlay
      logic lives as plain helper methods on `Creature`
      (`_instantiate_glb_rig`, `_flash_glb`) rather than a subclass, so
      it works whether a mob extends `Creature` or `Hostile` directly
      (GDScript has no multiple inheritance). `-- --species=deer` /
      `-- --hostile=goblin` force one kind for testing.
- [x] **M23 — HUD chrome, part 1: hearts, hunger, hotbar frames.**
      `hud.gd`'s health/hunger rows now draw `heart_*`/`drumstick_*`
      textures (`IconBar`, replacing the old flat-colored `SquareBar`)
      instead of plain squares — 2 points per icon, with a half state,
      since damage/regen/hunger-drain all move in odd amounts. The
      hotbar draws `hotbar_slot.png` per slot (it already bakes in its
      own border via edge shading) plus `slot_selected.png` — a real
      hollow-centre frame texture — over the selected one. Caught and
      fixed a real bug before it shipped: `slot_frame.png` looked like
      a border by name but is actually fully opaque edge-to-edge (no
      transparent hole), so layering it over every unselected slot as
      first written would have blanked out any item icon there — it's
      not used for the hotbar.
- [x] **M24 — HUD chrome, part 2: crosshair, break bar, logo, inventory
      slots.** `hud.gd`'s `Crosshair` now draws `crosshair.png`; its
      break-progress bar sources `break_bar.png` in two pieces (it's
      one 64x8 snapshot baked at a fixed ~60% fill, columns 2-39 solid
      fill / 40-63 empty track — not a width-clippable 0..1 template —
      so the track and fill segments are sourced separately via
      `draw_texture_rect_region` and recomposed at any real progress).
      The title screen swaps its "BLOCKY" text label for `logo.png`
      (pause/death keep plain text titles). `inventory_ui.gd`'s
      `SlotView` now uses `slot_frame.png` for its background (the
      landing spot `slot_frame.png` turned out to actually fit — see
      M23) and `slot_selected.png` to mark the result slot, replacing
      the old flat-rect borders.
      **Deliberately skipped, checked by inspecting actual pixel
      data**: `button.png`/`button_hover.png` have the literal word
      "PLAY" baked into them (fine for one title-screen action, wrong
      under "Quit"/"Resume"/"Save"/etc, so not worth wiring for a
      single button); `sound_slider.png` is one snapshot with the
      grabber and fill baked at a fixed ~70%, no separate track/
      grabber layers, so it can't represent a real dynamic volume
      value; `message_text.png` is baked with the example text "IRON
      PICKAXE", not a blank backdrop; `inventory_panel.png` bakes in
      "INVENTORY"/"CRAFTING" headings and a fixed-size grid that won't
      line up with our dynamically-sized slot layout (2x2 vs 3x3
      crafting, 27+9 inventory slots). Ryann confirmed: skip all four
      rather than force a mismatched fit.
- [x] **M25 — Environment props.** Rocks, grass tufts, flower patches,
      mushroom clusters and reeds now grow as `blocky/models/*.glb`
      decoration, deterministic per world column exactly like trees
      (`WorldGen.PROPS`/`REEDS_*`, tried in `fill_chunk()`, one prop
      per column max, skipping any column a tree already claimed).
      Ryann chose to keep trees as voxel Log/Leaves blocks — fully
      minable, since Log feeds the whole crafting chain — rather than
      switch to the nicer-silhouette GLB pine/broadleaf/crooked-tree
      props, which would've meant designing a new way to gather wood.
      PLAN.md's own Forest/Swamp/Water-edge prop split doesn't match
      this project's actual Plains/Forest/Desert/Tundra biomes (no
      Swamp exists), so it's adapted: grass tufts/flowers lean Plains,
      mushrooms join the mix in Forest, Desert/Tundra get sparse rock
      only, and reeds grow right at the waterline on the two temperate
      biomes. `world.gd` instantiates the GLBs as children of each
      `Chunk` node once its mesh lands (no collision — pure decoration,
      like PLAN.md's "environment = GLB props" cheap-and-controllable
      split says), so they stream in/out and get freed for free with
      the chunk. Caught a real perf regression with the project's own
      `--perf` instrumentation (not the movie-encoder's noisier
      numbers): placing props inline, unlike collision shapes, wasn't
      budgeted, so a burst of chunks finishing in the same frame at
      world-load could spike it — fixed by queuing newly-meshed chunks
      and instantiating only `max_props_per_frame` (4) chunks' worth
      per frame, mirroring the existing collision-shape queue's
      pattern exactly. Gave the queue its own measured slot in
      `print_perf()`'s breakdown (it had been silently folding into
      the "shapes" bucket) — now shows ~1-2 ms worst-case, confirming
      props aren't the dominant load-time cost.
- [x] **M26 — Wildlife weighting + Bird flight.** `world.WILDLIFE_WEIGHTS`
      gives each biome its own relative odds across the 5 species
      instead of a flat 1/5 each (Plains: a bit of everything; Forest:
      leans deer/fox/boar; Desert/Tundra: only the hardy ones, no
      boar, no deer in Desert) — picked in `_pick_wildlife()`, rolled
      from the spawn position's real biome. Bird now actually flies:
      it overrides `_physics_process()` entirely instead of reusing
      Creature's gravity/hop/cliff-check version, hovers ~3 blocks
      above the ground it spawned over (captured lazily on its first
      physics tick, since `_ready()` runs before world.gd positions a
      freshly spawned creature), and wanders/flees in the same
      idle/timer state Creature already tracks. Take_hit's ground-only
      "hop" (`velocity.y = 4.0`) is harmlessly inherited but never
      visible, since Bird's own height-correction overwrites velocity.y
      every frame before `move_and_slide()` runs.
- [x] **M27 — Shelter matters: torches and beds.** Two new real blocks
      (`Blocks.TORCH`, `Blocks.BED`) reuse the entire existing block
      pipeline as-is — inventory, hotbar/inventory icons, crafting,
      placement, breaking, save/load — rather than a parallel prop
      system, since the chunk mesher has no concept of a non-cube
      block (every id needs a full [top, side, bottom] atlas entry or
      it falls back to a stone look). Generated 4 new 16x16 tiles
      (torch_top/side, bed_top/side) with a small PIL script matching
      the existing flat-color palette, and extended the shared
      `blocks_atlas.png` from 4x4 to 4x5 tiles (`BlockAtlas.ROWS` 4→5)
      to fit them — existing tile UVs keep working unchanged since the
      math is proportional to the atlas's own (now taller) size.
      Torch: `Coal + Stick → 4 Torches`. A placed Torch spawns a
      companion `OmniLight3D` (`world._add_torch_light`, keyed by
      block position, not tied to chunk streaming so it doesn't need
      re-creating every time its chunk comes back into view) and
      pushes night-hunter spawn points away (`_near_a_torch`,
      `TORCH_HOSTILE_AVOID_RADIUS` = 10 blocks) — breaking it removes
      the light. Bed: `3 Planks in a row → 1 Bed` (needs a workbench —
      the 3-wide shape doesn't fit the 2x2 pocket grid). Right-clicking
      one (same pattern as Workbench's special right-click) emits
      `player.sleep_requested`; `main._try_sleep()` skips straight to
      the next dawn (`day_night.skip_to_morning()`) if it's night, or
      shows "Can't sleep now" by day — no "monsters nearby" block yet
      (see M34).
      Shades-can't-breach-a-wall turned out to already be true
      structurally (physics collision blocks them regardless of AI;
      their only mobility trick is a 1-block hop, not wall-scaling) —
      verified rather than rebuilt, with a new permanent selftest phase
      (a walled-in player takes zero damage from a hunter chasing it
      for 2 real seconds) rather than just asserted.
      Verified: 4 new selftest phases (frames 850-1020) covering
      craft→place→light→avoid→break for the torch, craft-needs-bench
      →place for the bed, sleep at noon (no-op) vs at night (skips to
      dawn, day count increments), and the shelter-breach check above
      — plus screenshots confirming the torch/bed icons and the
      torch's actual light bathing the surroundings in warm color.
      Hit and fixed a real GDScript gotcha while writing the new phases:
      `var x := main.day_night.time_of_day` fails to parse because
      `main` is declared as the generic `Node` type in selftest.gd, so
      the property's type can't be inferred — needed `var x: float =`
      instead (same class of bug noted in project memory before).
- [x] **M28 — Tool durability, and the sword is a real weapon now.**
      `Blocks.SWORD` (`2 Planks + 1 Stick`, needs a workbench — 3 rows
      tall, doesn't fit the pocket grid) is a real inventory item now
      instead of a permanently-attached cosmetic: `player._sword`
      (still the same `short_sword.glb`) is only `.visible` while
      `held_id() == Blocks.SWORD`, checked once a physics frame. Held,
      it hits for `SWORD_DAMAGE` (4, vs. a fist's 1) on a slower
      `SWORD_COOLDOWN` (0.5s vs. 0.35s) — genuinely a different, better
      weapon, not just a reskin.
      Durability lives on `Player` (`tool_durability: {id: uses left}`),
      not in `Inventory` itself — the inventory is flat parallel
      `_ids`/`_counts` arrays with no room for per-slot metadata, and
      giving it that would mean stacks of the same tool ID could carry
      *different* wear, breaking `Inventory.add()`'s assumption that
      same-id stacks are interchangeable. Scope trade-off, stated
      plainly: two of the same tool share one wear counter instead of
      wearing independently — doesn't matter much in practice since
      players rarely carry duplicates of the same tool. `_use_tool(id)`
      is a no-op for anything without a `Blocks.DURABILITY` entry (raw
      materials, blocks, ...); pickaxes/axes call it on every completed
      block break, the sword on every landed hit; a tool that hits 0
      uses disappears from the inventory with a "X broke!" HUD message.
      Persists across save/load and respawn (dying doesn't repair your
      tools) but resets on a new game. Also added a small durability
      bar under any damaged hotbar item (green → red as it wears down;
      undamaged/non-wearing items show no bar, matching Minecraft) —
      without it the whole mechanic would be invisible to a player.
      Verified: 5 new selftest phases (frames 1030-1060) covering
      craft-needs-a-bench, sword damage vs. fist damage, model
      visibility toggling correctly across a slot switch (checked a
      frame *after* each `select_slot()`, not the same frame — it
      raced `Player._physics_process`'s own update at first, a real
      bug the test caught before it shipped), durability ticking down
      one hit at a time, and both the sword and a pickaxe disappearing
      at 0 durability — plus a screenshot of the durability bar
      rendering (green, lightly worn) under the hotbar sword icon.
- [x] **M29 — Background music.** `sfx.gd` gains a `"music"` sound
      alongside every synthesized sound effect — same philosophy, zero
      audio files, everything built from sine/noise generators at
      startup. `_music_loop()` walks a C-major-pentatonic scale
      (every note in a pentatonic scale sounds fine next to any other,
      so a random walk can't land on anything dissonant) for a slow,
      sparse melody, resolving back to the tonic at the phrase's end
      so the loop point feels like a real musical rest instead of a
      cut, over a gently circling root/fifth/root/third bass drone an
      octave down — both just plain sine `_tone()` calls with the same
      exponential-decay "bell" envelope every percussive sound effect
      already uses, held longer and pitched into a scale instead of
      used for an impact. Plays continuously and quietly on its own
      "Music" audio bus (`MUSIC_DB = -20`, well under SFX), through the
      same volume slider that already controls SFX (`Sfx.set_volume()`
      now sets both buses) rather than adding a second one.
      Verified: a new frame-1 selftest check that the music player
      exists and is actually playing at boot, plus the full existing
      suite unaffected (nothing asserts exact waveform content, only
      play counts/booleans, so shifting the shared seeded RNG's call
      sequence by inserting the new generator doesn't break anything).
- [x] **M30 — Furnace: iron ore actually needs smelting now.** Breaking
      Iron Ore used to hand you usable Iron directly
      (`Blocks.DROP_OF[IRON_ORE] = IRON`); that entry is gone, so
      breaking it now drops raw Iron Ore (reusing the block's own id —
      `DROP_OF.get(id, id)` already defaults to "drops itself"; no new
      item or art needed) and only a `Blocks.FURNACE`
      (`8 Stone in a ring → 1 Furnace`, needs a workbench) turns it into
      Iron. Generated `furnace_top`/`furnace_side.png` the same way as
      the torch/bed tiles (M27) and extended the shared atlas again,
      4x5 → 4x6 (`BlockAtlas.ROWS` 5→6).
      The furnace screen isn't the shaped crafting grid — smelting
      isn't a pattern, it's just "the right two ingredients" — so
      `InventoryUI` gained a `mode: String` ("pocket"/"bench"/"furnace",
      replacing the old `bench_mode: bool`) and two new layout/result
      branches (`_build_furnace_section()`, `_can_smelt()`) that swap
      in two fixed slots (ore, fuel) instead, while reusing the exact
      same `SlotView` component, inventory grid and hotbar rendering as
      pocket/bench crafting. Right-clicking a Furnace opens it via the
      same pattern as Workbench/Bed (`player.furnace_used` →
      `main.State.FURNACE`).
      Verified: new selftest phases covering the drop-changed assertion,
      craft-needs-a-bench, the screen opening, and a full
      ore+fuel→Iron→consumed smelt — but not with a live third-person
      raycast the way the Workbench test proves its click detection,
      after real debugging (not a guess): diagnostics confirmed the
      furnace block placed and persisted correctly every time, but the
      very next `_aim_ray()` sometimes landed somewhere else entirely
      (once on a tree's leaves) — the `SpringArm3D` third-person camera
      pulls in to avoid clipping when something's placed close to its
      own arm, silently moving the ray's origin before the "click".
      Since Furnace's right-click branch is structurally identical to
      Workbench's already-raycast-tested one (same function, same
      pattern, different `Blocks` id), that mechanism doesn't need
      re-proving — this instead calls `player.furnace_used.emit()`
      directly, the same way the Bed/sleep test already does, and
      focuses the raycast-dependent proof where it already lives.
- [x] **M31 — Swimming.** The Water plane (`main.tscn`, a flat visual
      mesh with no collision, following the player's x/z at a fixed
      `y = 19.9`) never had any gameplay hook — the player fell straight
      through it and took full fall damage hitting the seabed
      underneath. `player.gd` now checks `global_position.y <
      WATER_SURFACE_Y` every physics frame (`WorldGen.SEA_LEVEL + 0.9`,
      matching the plane's own y exactly, so it doesn't drift out of
      sync with world-gen's own sea level constant) and swaps in gentler
      physics while it's true: `WATER_GRAVITY` (4.0, vs. dry `GRAVITY`
      22.0) sinks you slowly instead of dropping, capped at `-SWIM_SPEED`
      so swimming up always wins against sinking; holding jump rises at
      `SWIM_RISE_SPEED`; horizontal movement drops to the slower
      `SWIM_SPEED` in any direction. `_check_fall_damage()` treats being
      in water as an immediate safe "landing" (resets `_peak_y`, sets
      `_was_on_floor = true`) the moment you enter it, so diving from a
      cliff into water never hurts, and swimming down to touch the
      actual seabed afterward doesn't retroactively charge the drop.
      One check is a single flat "feet below the water plane" test, not
      Minecraft's separate waist-deep/fully-submerged states — wading
      through ankle-deep water uses full swim physics too, a stated
      simplification, not a bug. No breath meter/drowning and no
      underwater visual effects (fog tint, muffled audio) — scope
      trade-offs in the same spirit as M27 skipping "monsters nearby"
      for sleep: the core mechanic (being in water changes how you
      move, and you control your depth) is what "swimmable" most
      literally asks for.
      Added `test_swim_up` (mirroring the existing `test_move`/
      `test_run`/`test_hold_break` dev-only override pattern) since the
      real swim-up check reads `Input.is_action_pressed("jump")`, which
      — like the existing dry-land jump — is unreachable under
      `--no-input`; there was no prior selftest precedent for testing
      jump-driven behavior at all.
      Verified: a new selftest phase (frames 1090-1100) that searches
      outward from the player's position for a real ocean column
      (`world.height_at() <= SEA_LEVEL - 1`, not a hardcoded location),
      dives in at -20 vertical velocity as if falling from a height, and
      confirms `_in_water` is true, the sink speed is capped nowhere
      near the dive speed, holding jump reaches exactly
      `SWIM_RISE_SPEED`, horizontal speed is exactly `SWIM_SPEED`, and
      health is completely unchanged after the "fall" — plus a
      screenshot confirming the player visibly swimming at the correct
      depth near a real shoreline.

- [x] **M32 — Jump and sprint limb animation.** `player.gd`'s
      `_animate_limbs` now takes on_floor/vel_y: airborne, legs/arms lerp
      to a jump pose (rising vs. falling read off vel_y's sign) instead of
      freezing mid-stride, and landing resumes the walk/run swing
      automatically. Added a small vertical model bob while moving (bigger
      while sprinting) on top of the existing lean/FOV-widen sprint tells,
      and `player.test_jump` (mirrors `test_swim_up`) since jump is
      normally unreachable under `--no-input`. Verified with a recorded
      movie (mid-stride running pose, airborne arms-up/legs-in pose) plus
      the full `--selftest` suite passing.
- [x] **M33 — The proper GLB water/shoreline system.** Replaced the flat
      1000x1000 `PlaneMesh` (`main.tscn`'s old `Water` node) with
      `blocky/models/water_tile.glb` (basin + surface + foam trim + lily
      pads) tiled over every underwater column, reusing the exact
      environment-prop pipeline from M25 (`WorldGen.fill_chunk`'s `props`
      array, `world.gd`'s budgeted instantiate queue). The tile is a 2x2-
      block footprint, so it's placed on a checkerboard (every other
      lx/lz) to tile edge-to-edge with no gaps, and always at a fixed
      rotation — a random one, like other props get, would break the
      tile's asymmetric foam trim lining up between neighbors. Its
      "surface" sub-mesh sits 0.5625 above the tile's own origin (found by
      parsing the glTF directly), so the origin is offset down by that to
      land the surface at the old plane's exact height
      (`WorldGen.SEA_LEVEL + 0.9`) — swim physics (`player.gd`'s
      `WATER_SURFACE_Y`) already used that same constant independently of
      the visual mesh, so gameplay didn't need to change at all.
      Water tiles are excluded from the fragile-prop removal-on-dig path
      (`world._instantiate_props` skips registering them in `_prop_nodes`)
      since, unlike a grass tuft, water shouldn't vanish just because you
      excavate the seafloor under it.
      Caught a real perf regression with `--perf --radius=8` before
      calling this done (this project's own established measure-first
      habit, see M13/M25): a fully-underwater chunk can carry up to 64
      tile instances vs. a handful of sparse decorative props, and 4 such
      chunks landing in the same frame at world-load spiked the props
      budget from M25's documented ~1-2 ms to 10.4 ms (worst frame 35.8 ms
      vs. the M13 target). Halved `max_props_per_frame` (4 → 2) as the
      minimal fix — cut props to 4.4 ms and worst frame to 30.6 ms, and
      confirmed with the perf log that it's a one-time load-in spike (the
      chunk queue empties and the worst-frame figure never climbs again
      afterward), not a sustained cost.
      Verified: full `--selftest` suite unaffected (swim mechanics read
      the physics constant directly, never the visual mesh), a throwaway
      `tools/find_water.gd` dev tool (mirrors `find_cave.gd`'s pattern) to
      locate a real shoreline column for screenshotting, and a recorded
      movie confirming the tiled water renders with visible foam-ripple
      texture and lily pads, seamless to the horizon with no gaps or
      floating geometry.
- [x] **M34 — Sleeping blocks on "monsters nearby".** `main._try_sleep()`
      now also refuses (message: "Too dangerous to sleep") if
      `world.hostile_near(player.global_position, Hostile.SIGHT)` finds a
      live hostile within 18 blocks — the same range a hostile itself
      uses to notice and start chasing the player, so "too dangerous to
      sleep" and "close enough to be hunting you" are the same threshold
      by construction rather than a second tuned number. `hostile_near()`
      just walks `world._hostiles.get_children()` — mirrors
      `hostile_count()` right next to it.
      Verified: two new selftest phases — sleep attempted with a hostile
      spawned 5 blocks away (day count unchanged) and again with one 30
      blocks away (day advances normally) — plus the full suite otherwise
      unaffected. Caught a real bug in the test itself while writing it,
      not the game: `queue_free()` defers removal, so re-checking
      "sleep works with nothing nearby" in the same physics frame still
      saw the just-freed nearby hostile and failed; switched that one
      cleanup call to immediate `.free()`.
- [x] **M36 — Breath meter, drowning, underwater fog/muffled audio.**
      Closes the M31 scope trim. A new `player.head_submerged` (public,
      distinct from the private `_in_water` that drives swim physics)
      checks the CAMERA PIVOT's height against `WATER_SURFACE_Y`, not the
      feet — wading in shin-deep water shouldn't cost breath the way it
      already doesn't block movement. `_tick_breath()` mirrors
      `_tick_hunger()`'s shape exactly: breath drains every
      `BREATH_DRAIN_SECONDS` while submerged, regenerates every
      `BREATH_REGEN_SECONDS` once it isn't, and at 0 breath still
      submerged, `take_damage(1)` fires every `DROWN_SECONDS` — same
      "timer accumulates, subtract and fire on threshold" shape as the
      existing starve timer. Breath persists in the save file like health/
      hunger.
      HUD: a third `IconBar` (`hud.gd`'s existing class, already shared by
      hearts and hunger) using three new hand-generated 9x9 bubble icons
      (`blocky/textures/ui/bubble_*.png` — no such art existed in the
      vendored asset pack; generated with a one-off PIL script matching
      the existing icon style pixel-for-pixel: same silhouette-with-
      outline/mid/highlight construction as `heart_*`, same "drained"
      grey palette `heart_empty`/`drumstick_empty` already share, script
      itself not committed, matching the M27 torch/bed tile precedent).
      Sits above the hunger row and only shows once breath has actually
      dropped, same as Minecraft's bubble meter.
      Underwater fog: a translucent blue `ColorRect` on the HUD canvas
      that fades in/out with `head_submerged`, the same screen-tint
      technique `_damage_flash` already uses for the hurt flash — chosen
      over touching the shared `WorldEnvironment` fog properties, which
      `day_night.gd` already drives every frame; a second system fighting
      over the same resource would have been real coupling for no
      visual gain a screen tint doesn't already give.
      Muffled audio: `sfx.gd` gets an `AudioEffectLowPassFilter` on both
      the SFX and Music buses (added disabled, alongside the existing
      master-bus limiter), toggled by `Sfx.set_underwater()` — called
      once a frame from `main._process` with `player.head_submerged`.
      Caught and fixed a real bug before it shipped, the same way M23's
      `slot_frame.png` mistake was caught: breath drain and regen
      originally shared one timer variable, so surfacing right after a
      drain tick carried that tick's leftover fractional time straight
      into the regen accumulator, firing a burst of bogus extra regen
      points in the first couple of frames after surfacing — a selftest
      assertion showing breath jump by 4 instead of the expected ~2
      caught it; split into independent `_breath_drain_timer` /
      `_breath_regen_timer`, the same reason `_tick_hunger` already keeps
      its own drain/regen/starve timers apart.
      Verified: full `--selftest` suite plus new phases covering
      submerging (checked a frame after the position change, not the
      same frame — the same race M28's sword-visibility test hit),
      draining, drowning damage, surfacing, regen, and the audio-muffle
      toggle in both directions; screenshots confirming the bubble row
      renders correctly above the hunger row (only when breath is below
      max) and the underwater tint visibly washes the screen blue.

This closes out every item on the original backlog. See "Next" below
for what's left — all either blocked on missing inputs (new art/audio
that doesn't exist yet) or deliberate, stated scope trims from
milestones above, not gaps that were missed.

## Next — pick a direction

- [ ] Generic-label button/slider/message/panel art, if that ever gets
      generated — the current button/sound-slider/message-text/
      inventory-panel assets bake in example content that doesn't fit
      (see M24).
- [ ] GLB pine/broadleaf/crooked trees, if wood-gathering ever gets a
      non-block-mining redesign (see M25) — voxel trees stay for now.
- [ ] Per-slot tool durability (see M28's scope trade-off), if stacked
      duplicate tools wearing independently ever turns out to matter.
