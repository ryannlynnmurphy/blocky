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

## Next (in order)

- [ ] M9 — Combat: a punch that hurts creatures; creatures have health,
      flinch, and can die (and drop something).
- [ ] M10 — Player stats: health bar, taking damage, respawn.
- [ ] M11 — RPG progression: XP from creatures, levels raise health.
- [ ] M12 — Saving: world edits, inventory and position survive a restart.

## Later (not yet)

Hostile creatures, tools/crafting, sound, greedy meshing / performance
work, larger view distance.
