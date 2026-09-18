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

## Next — pick a direction

The original wish list is covered. Candidates, roughly in order of
how much they'd change the feel of the game:

- [ ] Shelter matters: Shades can't path through walls but will wait;
      beds to skip the night; torches that keep them away.
- [ ] Tool durability and a held-item model in the hand.
- [ ] A simple generated music loop.
- [ ] Furnace: smelt iron ore properly; torches from coal + sticks.
- [ ] Water you can swim in.
- [ ] Title screen with New Game / Continue and a seed box.
