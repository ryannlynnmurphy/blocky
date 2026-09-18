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

## Next (in order)

- [ ] M6 — Biomes: temperature/moisture noise picks grass color, tree
      density, and block palette per region.
- [ ] M7 — First creature: a wandering animal you can bump into.
- [ ] M8 — Inventory: breaking a block gives you that block; placing
      spends it.

## Later (not yet)

Combat, RPG progression, saving, sound, greedy meshing / performance work.
