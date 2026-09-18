# Voxel RPG

An original voxel RPG built in **Godot 4** (GDScript). Inspired by the
exploration, chunky aesthetic, and sense of adventure of Cube World and
Minecraft — but its own game.

## Running it

1. Install Godot 4.7+ (standard build, not .NET): `winget install GodotEngine.GodotEngine`
2. Open Godot, click **Import**, pick this folder's `project.godot`.
3. Press **F5** (Run Project).

From a terminal, without the editor:

```
godot --path . 
```

## Controls

| Input | Action |
|-------|--------|
| W A S D | Move (relative to the camera) |
| Mouse | Look |
| Space | Jump |
| Shift | Run |
| Left click | Punch a creature under the crosshair (within 3 blocks) |
| Left click (hold) | Break the highlighted block — leaves take 0.25 s, dirt 0.5 s, stone 1.5 s. It pops out as an item that flies to you when you're close |
| Right click | Place the selected block |
| 1–8 / mouse wheel | Pick which block to place (you must have one — break blocks to collect them) |
| E | Eat one Meat (+4 hunger) |
| Tab | Inventory and crafting screen (Esc or Tab closes) |
| F5 | Save now (it also autosaves every 30 s and when you close the window) |
| T (hold) | Fast-forward time (watch the sun set) |

You have 10 health (the red squares) and 10 hunger (the orange ones).
Hunger drops one point every 45 s, three times faster while sprinting.
At 7+ hunger you regain 1 health every 4 s; at 0 you lose 1 health every
10 s (down to 1). Falling more than 3 blocks hurts; at 0 health you
respawn where you started, keeping your inventory.

Killing creatures quietly makes you tougher: every 10×N kills-worth of
XP adds 2 max health (the health row grows). There is no level display
by design.

## Crafting and tools

Press Tab. Recipes are a list, not a grid:

| Ingredients | Result | Where |
|---|---|---|
| 1 Log | 4 Planks | anywhere |
| 2 Planks | 4 Sticks | anywhere |
| 4 Planks | 1 Workbench (hotbar slot 9, place it) | anywhere |
| 3 Planks + 2 Sticks | Wooden Pickaxe / Wooden Axe | within 3 blocks of a Workbench |
| 3 Stone + 2 Sticks | Stone Pickaxe / Stone Axe | within 3 blocks of a Workbench |

Tools aren't equipped — owning one is enough. A pickaxe speeds up stone
(wood ×2.5, stone ×4); an axe speeds up logs, planks and workbenches.
Stone takes 3 s by hand and **drops nothing without a pickaxe**.
Recipes live in `scripts/recipes.gd`; hardness and tool classes in
`scripts/blocks.gd`.

## Saving

Your game is saved to one readable JSON file:
`%APPDATA%\Godot\app_userdata\Voxel RPG\save.json`. It holds the world
seed, every block you changed (the terrain itself is regenerated), your
position, health, level, XP, inventory, and the time of day. The game
loads it automatically at startup. To start over, delete that file or
run with `-- --fresh`.
| Esc | Free / re-capture the mouse |

## Dev switches

Anything after `--` on the command line is for our scripts, not Godot:

```
godot --path . -- --day-length=5       a day lasts 5 seconds instead of 10 minutes
godot --path . -- --spawn=-300,-20     spawn at that x,z column
godot --path . -- --critter            put one animal right in front of you
godot --path . -- --fresh              ignore the save file, start a new game
godot --path . -- --perf --radius=8    print chunk generation/meshing timings
godot --path . -- --selftest --no-input --fresh
                                       auto-run break/place, punch/kill/pickup,
                                       fall/eat/die/respawn, XP/level-up and
                                       save/load, printing results; --no-input keeps
                                       your mouse out of recordings
godot --headless --path . --script tools/biome_survey.gd   print a biome map
```

## Where things live

```
project.godot        engine settings (window size, main scene, crisp-pixel rendering)
scenes/main.tscn     the level: sky, sun, world, water, player, HUD
scenes/player.tscn   the character's body, collision capsule and camera rig
scenes/creature.tscn a critter's body and collision box
scripts/main.gd      wires everything together, picks a spawn point, saves/loads
scripts/save_game.gd reads/writes the JSON save file
scripts/blocks.gd    block registry: IDs, names, colors
scripts/world_gen.gd noise terrain, biomes, grass tint, trees -> fills a chunk
tools/               headless dev scripts (not part of the game)
scripts/chunk.gd     turns one chunk's block IDs into a mesh (visible faces only)
scripts/world.gd     owns all chunks, streams them around the player, get/set block,
                     spawns/despawns creatures
scripts/creature.gd  critter brain: idle / wander / flee, health, hop steps, avoid cliffs + water
scripts/drop.gd      a dropped item on the ground; walk into it to pick it up
scripts/player.gd    movement, camera, aiming, break/place, punch, health, respawn, XP/levels
scripts/inventory.gd what you're carrying: a count per block/item ID
scripts/recipes.gd   crafting recipes (ingredients -> result, workbench or not)
scripts/inventory_ui.gd  the Tab screen: inventory list + Craft buttons
scripts/day_night.gd sun/moon orbit, sky + light color over the day
scripts/hud.gd       crosshair, hotbar, clock, hints
```

## Physics layers

| Layer | Who | Notes |
|-------|-----|-------|
| 1 | terrain chunks | camera arm and block-aiming rays only look here |
| 2 | creatures | player collides with 1+2, creatures with 1+2 |

## How chunks stream in (performance)

Chunks within `view_radius` (8 → 128 blocks) of the player are drawn;
only those within `collision_radius` (3) get a physics shape, because
that's the one expensive step that must run on the main thread. The
pipeline for a new chunk:

1. `update_chunks` creates an empty `Chunk` node and queues it (nearest first).
2. A worker thread generates its block data (`GenJob`, look-ahead of 8).
3. When it and its four neighbours have data, a worker thread meshes it
   (`MeshJob`: `Chunk.build_arrays` → `Chunk.make_mesh`).
4. The main thread puts the mesh on the node and, if it's near you,
   builds the collision shape — at most 3 shapes per frame.

Edits skip the threads and rebuild synchronously so they feel instant;
a `version` counter drops any thread result that predates the edit.
`-- --perf` prints timings every 60 frames.

## How the world is stored

The world is a grid of **chunks**, each 16 wide x 64 tall x 16 deep. A chunk
is just a `PackedByteArray` of 16,384 numbers — each number is a block ID
from `blocks.gd` (0 = air). To draw a chunk we don't draw 16,384 cubes; we
only emit the cube faces that touch air, and glue them into one mesh.

See `ROADMAP.md` for what is done and what comes next.
