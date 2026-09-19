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
      shows "Can't sleep now" by day — no "monsters nearby" block yet.
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

## Next — pick a direction

The original wish list is covered. Candidates, roughly in order of
how much they'd change the feel of the game:

- [ ] Generic-label button/slider/message/panel art, if that ever gets
      generated — the current button/sound-slider/message-text/
      inventory-panel assets bake in example content that doesn't fit
      (see M24).
- [ ] GLB pine/broadleaf/crooked trees, if wood-gathering ever gets a
      non-block-mining redesign (see M25) — voxel trees stay for now.
- [ ] Tool durability; give the sword an actual swing/hitbox.
- [ ] A simple generated music loop.
- [ ] Furnace: smelt iron ore properly (torches already craft from
      coal + sticks — see M27).
- [ ] Water you can swim in (or the proper GLB water/shoreline system).
- [ ] Sleeping could block on "monsters nearby" like Minecraft (M27
      skipped this for scope).
